#!/usr/bin/env python3
"""design-review-server — localhost review surface for spec/plan/design gates.

Serves the design-review app over 127.0.0.1 and persists the user's review
output into the feature directory:

  design-comments.json   — anchored feedback batched in the browser
  design-verdict.json    — the gate verdict, sha-bound to the exact artifact
                           bytes present at verdict time (server-side hashes,
                           never client-supplied)

Endpoints:
  GET  /                      → the review app (scripts/design-review.html)
  GET  /artifact/<name>       → spec.md | plan.md | design.html from the feature dir
  GET  /meta                  → feature slug, round, per-artifact sha256 (short)
  GET  /comments              → current design-comments.json (resume support)
  POST /comments              → write design-comments.json
  POST /verdict               → write design-verdict.json; REJECTED if any
                                comment in the payload is still open (the
                                approve-needs-zero-open-comments rule is
                                enforced server-side, not just in the UI)

Stdlib only. Binds 127.0.0.1 exclusively. Started/stopped via design-review.sh.
"""
import argparse
import hashlib
import html as _html
import json
import os
import re
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ARTIFACTS = ("spec.md", "plan.md", "design.html")


# ── server-side markdown → HTML (no external deps, fully offline) ────────
# A compact, DEFENSIVE renderer for the constructs spec.md / plan.md actually
# use: frontmatter strip, ATX headings, fenced code (incl. ASCII diagrams),
# pipe tables, lists, blockquote, hr, and inline bold/code/links. Anything it
# doesn't recognize falls through as a paragraph — it never throws on input.
def _inline(s):
    s = _html.escape(s, quote=False)
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)',
               r'<a href="\2" target="_blank" rel="noopener">\1</a>', s)
    return s


def _strip_frontmatter(text):
    if text.startswith('---\n'):
        end = text.find('\n---', 3)
        if end != -1:
            nl = text.find('\n', end + 1)
            return text[nl + 1:] if nl != -1 else ''
    return text


def render_markdown(text):
    lines = _strip_frontmatter(text).split('\n')
    out, para, i, n = [], [], 0, len(lines)

    def flush():
        if para:
            out.append('<p>' + _inline(' '.join(para)) + '</p>')
            para.clear()

    list_re = r'^\s*(?:[-*]|\d+\.)\s+'
    while i < n:
        line = lines[i]
        if line.lstrip().startswith('```'):                      # fenced code / ASCII diagram
            flush(); i += 1; code = []
            while i < n and not lines[i].lstrip().startswith('```'):
                code.append(lines[i]); i += 1
            i += 1
            out.append('<pre><code>' + _html.escape('\n'.join(code)) + '</code></pre>')
            continue
        m = re.match(r'^(#{1,6})\s+(.*)$', line)
        if m:                                                    # heading
            flush(); lvl = len(m.group(1))
            out.append('<h%d>%s</h%d>' % (lvl, _inline(m.group(2).strip()), lvl)); i += 1; continue
        if '|' in line and i + 1 < n and re.match(
                r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$', lines[i + 1]):  # pipe table
            flush()
            def cells(row):
                row = row.strip().strip('|')
                return [c.strip() for c in row.split('|')]
            header = cells(line); i += 2; body = []
            while i < n and '|' in lines[i] and lines[i].strip():
                body.append(cells(lines[i])); i += 1
            t = ['<table><thead><tr>'] + ['<th>' + _inline(c) + '</th>' for c in header] + ['</tr></thead><tbody>']
            for r in body:
                t.append('<tr>' + ''.join('<td>' + _inline(c) + '</td>' for c in r) + '</tr>')
            t.append('</tbody></table>'); out.append(''.join(t)); continue
        if re.match(r'^\s*---+\s*$', line):                      # horizontal rule
            flush(); out.append('<hr>'); i += 1; continue
        if line.lstrip().startswith('>'):                        # blockquote
            flush(); bq = []
            while i < n and lines[i].lstrip().startswith('>'):
                bq.append(re.sub(r'^\s*>\s?', '', lines[i])); i += 1
            out.append('<blockquote>' + _inline(' '.join(bq)) + '</blockquote>'); continue
        if re.match(list_re, line):                              # list (ul/ol)
            flush(); ordered = bool(re.match(r'^\s*\d+\.\s+', line))
            tag = 'ol' if ordered else 'ul'; items = []
            while i < n and re.match(list_re, lines[i]):
                items.append('<li>' + _inline(re.sub(list_re, '', lines[i])) + '</li>'); i += 1
            out.append('<%s>%s</%s>' % (tag, ''.join(items), tag)); continue
        if not line.strip():                                     # blank → paragraph break
            flush(); i += 1; continue
        para.append(line.strip()); i += 1
    flush()
    return '\n'.join(out)


def sha256_file(path):
    if not os.path.isfile(path):
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class ReviewHandler(BaseHTTPRequestHandler):
    feature_dir = None
    app_path = None
    round_no = 1

    # ── helpers ──────────────────────────────────────────────────────
    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0 or length > 2_000_000:
            return None
        try:
            return json.loads(self.rfile.read(length))
        except (json.JSONDecodeError, ValueError):
            return None

    def _artifact_path(self, name):
        # strict allowlist — no path traversal surface
        return os.path.join(self.feature_dir, name) if name in ARTIFACTS else None

    def _load_comments(self):
        p = os.path.join(self.feature_dir, "design-comments.json")
        if not os.path.isfile(p):
            return []
        try:
            with open(p, "r", encoding="utf-8") as f:
                payload = json.load(f)
            comments = payload.get("comments", [])
            return comments if isinstance(comments, list) else []
        except (OSError, ValueError):
            return []

    def log_message(self, fmt, *args):  # quiet — orchestrator reads files, not logs
        pass

    # ── GET ──────────────────────────────────────────────────────────
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            try:
                with open(self.app_path, "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            except OSError:
                self._send(500, {"error": "review app missing: %s" % self.app_path})
        elif self.path.startswith("/artifact/"):
            p = self._artifact_path(self.path[len("/artifact/"):])
            if p and os.path.isfile(p):
                ctype = "text/html; charset=utf-8" if p.endswith(".html") else "text/plain; charset=utf-8"
                with open(p, "rb") as f:
                    self._send(200, f.read(), ctype)
            else:
                self._send(404, {"error": "no such artifact"})
        elif self.path.startswith("/render/"):
            # server-side markdown → HTML; the browser injects this as-is (no CDN renderer)
            p = self._artifact_path(self.path[len("/render/"):])
            if p and os.path.isfile(p) and p.endswith(".md"):
                with open(p, "r", encoding="utf-8") as f:
                    self._send(200, render_markdown(f.read()).encode(), "text/html; charset=utf-8")
            else:
                self._send(404, {"error": "not a renderable markdown artifact"})
        elif self.path == "/meta":
            self._send(200, {
                "feature": os.path.basename(self.feature_dir.rstrip("/")),
                "round": self.round_no,
                "artifacts": {
                    name: {"exists": os.path.isfile(os.path.join(self.feature_dir, name)),
                           "sha256": sha256_file(os.path.join(self.feature_dir, name))}
                    for name in ARTIFACTS
                },
            })
        elif self.path == "/comments":
            p = os.path.join(self.feature_dir, "design-comments.json")
            if os.path.isfile(p):
                with open(p, "rb") as f:
                    self._send(200, f.read())
            else:
                self._send(200, {"round": self.round_no, "comments": []})
        else:
            self._send(404, {"error": "not found"})

    # ── POST ─────────────────────────────────────────────────────────
    def do_POST(self):
        body = self._read_body()
        if body is None:
            self._send(400, {"error": "bad or oversized JSON body"})
            return

        if self.path == "/comments":
            comments = body.get("comments", [])
            if not isinstance(comments, list) or not all(isinstance(c, dict) for c in comments):
                self._send(400, {"error": "comments must be a list of objects"})
                return
            payload = {
                "round": self.round_no,
                "saved_at": now_iso(),
                "comments": comments,
            }
            self._write_json("design-comments.json", payload)
            self._send(200, {"ok": True, "count": len(payload["comments"])})

        elif self.path == "/verdict":
            verdict = body.get("verdict")
            if verdict not in ("approved", "changes-requested"):
                self._send(400, {"error": "verdict must be approved|changes-requested"})
                return
            # The comments file is authoritative. The browser persists its
            # current state before posting a verdict; a crafted verdict request
            # cannot smuggle an empty array past already-saved open comments.
            comments = self._load_comments()
            open_comments = [c for c in comments if not c.get("resolved")]
            if verdict == "approved" and open_comments:
                # server-side enforcement — the UI disables the button, but the
                # rule must hold even against a hand-crafted request
                self._send(409, {"error": "approve rejected: %d open comment(s)" % len(open_comments)})
                return
            # persist the comment state alongside the verdict (final word)
            self._write_json("design-comments.json", {
                "round": self.round_no, "saved_at": now_iso(), "comments": comments,
            })
            record = {
                "verdict": verdict,
                "round": self.round_no,
                "ts": now_iso(),
                "comments_total": len(comments),
                "comments_open": len(open_comments),
                # authoritative server-side hashes of the bytes on disk NOW —
                # the approval is bound to exactly these artifact versions
                "spec_sha": sha256_file(os.path.join(self.feature_dir, "spec.md")),
                "plan_sha": sha256_file(os.path.join(self.feature_dir, "plan.md")),
                "design_sha": sha256_file(os.path.join(self.feature_dir, "design.html")),
            }
            self._write_json("design-verdict.json", record)
            self._send(200, {"ok": True, "verdict": verdict})
        else:
            self._send(404, {"error": "not found"})

    def _write_json(self, name, obj):
        p = os.path.join(self.feature_dir, name)
        tmp = p + ".tmp"
        with open(tmp, "w") as f:
            json.dump(obj, f, indent=2)
        os.replace(tmp, p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("feature_dir")
    ap.add_argument("--port", type=int, default=7341)
    ap.add_argument("--round", type=int, default=1)
    ap.add_argument("--app", required=True, help="path to design-review.html")
    args = ap.parse_args()

    if not os.path.isdir(args.feature_dir):
        print("feature dir not found: %s" % args.feature_dir, file=sys.stderr)
        sys.exit(1)

    ReviewHandler.feature_dir = os.path.abspath(args.feature_dir)
    ReviewHandler.app_path = os.path.abspath(args.app)
    ReviewHandler.round_no = args.round

    srv = ThreadingHTTPServer(("127.0.0.1", args.port), ReviewHandler)
    print("design-review serving %s on http://127.0.0.1:%d" % (args.feature_dir, args.port), flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
