import argparse, json, re, sqlite3, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

def db_connect(path):
    c = sqlite3.connect(path, check_same_thread=False)
    c.execute("create table if not exists bm(id integer primary key, url text unique, title text, tags text, created_at text)")
    c.commit(); return c

def row(r):
    return {"id": r[0], "url": r[1], "title": r[2], "tags": json.loads(r[3]), "created_at": r[4]}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, obj=None):
        body = b"" if obj is None else json.dumps(obj).encode()
        self.send_response(code)
        if obj is not None: self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        try: return json.loads(raw or b"{}")
        except ValueError: return None
    def route(self, method):
        u = urlparse(self.path); db = self.server.db
        m = re.fullmatch(r"/bookmarks/(\d+)", u.path)
        if method == "POST" and u.path == "/bookmarks":
            b = self.body()
            if not isinstance(b, dict): return self.send(400, {"error": "bad json"})
            url, title = b.get("url"), b.get("title")
            if not isinstance(url, str) or not re.match(r"https?://", url): return self.send(400, {"error": "bad url"})
            if not isinstance(title, str) or not title.strip(): return self.send(400, {"error": "bad title"})
            tags = sorted(set(b.get("tags") or []))
            try:
                cur = db.execute("insert into bm(url,title,tags,created_at) values(?,?,?,?)",
                    (url, title, json.dumps(tags), datetime.datetime.utcnow().isoformat() + "Z"))
                db.commit()
            except sqlite3.IntegrityError: return self.send(409, {"error": "duplicate url"})
            return self.send(201, row(db.execute("select * from bm where id=?", (cur.lastrowid,)).fetchone()))
        if method == "GET" and u.path == "/bookmarks":
            q = parse_qs(u.query); items = [row(r) for r in db.execute("select * from bm order by id")]
            if "tag" in q: items = [i for i in items if q["tag"][0] in i["tags"]]
            if "q" in q: items = [i for i in items if q["q"][0].lower() in i["title"].lower()]
            limit = min(int(q.get("limit", ["20"])[0]), 100); off = int(q.get("offset", ["0"])[0])
            return self.send(200, {"items": items[off:off + limit], "total": len(items)})
        if method == "GET" and u.path == "/tags":
            counts = {}
            for r in db.execute("select tags from bm"):
                for t in json.loads(r[0]): counts[t] = counts.get(t, 0) + 1
            return self.send(200, {"tags": [{"name": n, "count": c} for n, c in sorted(counts.items(), key=lambda x: (-x[1], x[0]))]})
        if m:
            r = db.execute("select * from bm where id=?", (int(m.group(1)),)).fetchone()
            if method == "GET": return self.send(200, row(r)) if r else self.send(404, {"error": "not found"})
            if method == "DELETE":
                if not r: return self.send(404, {"error": "not found"})
                db.execute("delete from bm where id=?", (r[0],)); db.commit(); return self.send(204)
            if method == "PATCH":
                b = self.body()
                if not isinstance(b, dict): return self.send(400, {"error": "bad json"})
                if not r: return self.send(404, {"error": "not found"})
                if "url" in b: return self.send(400, {"error": "url is immutable"})
                cur = row(r)
                if "title" in b:
                    if not isinstance(b["title"], str) or not b["title"].strip(): return self.send(400, {"error": "bad title"})
                    cur["title"] = b["title"]
                if "tags" in b: cur["tags"] = sorted(set(b["tags"]))
                db.execute("update bm set title=?, tags=? where id=?", (cur["title"], json.dumps(cur["tags"]), r[0])); db.commit()
                return self.send(200, cur)
        return self.send(404, {"error": "no route"})
    def do_GET(self): self.route("GET")
    def do_POST(self): self.route("POST")
    def do_PATCH(self): self.route("PATCH")
    def do_DELETE(self): self.route("DELETE")

if __name__ == "__main__":
    a = argparse.ArgumentParser(); a.add_argument("--port", type=int); a.add_argument("--db"); o = a.parse_args()
    s = ThreadingHTTPServer(("127.0.0.1", o.port), H); s.db = db_connect(o.db); s.serve_forever()
