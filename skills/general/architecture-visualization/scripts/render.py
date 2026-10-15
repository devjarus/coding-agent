#!/usr/bin/env python3
"""
render.py — validate a diagram IR (JSON) and render a self-contained HTML diagram.

Inspired by archify (github.com/tt-a1i/archify): the agent authors a typed JSON
intermediate representation (IR); this renderer validates it and produces a
zero-dependency HTML file with an inline SVG, a light/dark theme toggle, and a
PNG export button. Edits target the JSON IR, never the generated HTML.

Usage:
    python3 render.py <ir.json> [-o out.html]         # validate + render
    python3 render.py <ir.json> --check               # validate only (no output)

Stdlib only. No pip installs. Deterministic layout (no randomness).

Supported IR "type" values:
    architecture | workflow | dataflow | lifecycle   -> layered graph layout
    sequence                                          -> lifeline layout

See ../rules/ir-schema.md for the full schema.
"""

import argparse
import html
import json
import sys

LAYERED_TYPES = {"architecture", "workflow", "dataflow", "lifecycle"}
ALL_TYPES = LAYERED_TYPES | {"sequence"}

# ─── Validation ──────────────────────────────────────────────────────────────


class IRError(Exception):
    pass


def validate(ir):
    """Validate the IR. Raises IRError with an actionable message on failure."""
    errs = []
    if not isinstance(ir, dict):
        raise IRError("IR root must be a JSON object")

    dtype = ir.get("type")
    if dtype not in ALL_TYPES:
        errs.append(
            f"type: {dtype!r} is not one of {sorted(ALL_TYPES)}"
        )

    nodes = ir.get("nodes")
    if not isinstance(nodes, list) or not nodes:
        errs.append("nodes: must be a non-empty array")
        nodes = []

    ids = set()
    for i, n in enumerate(nodes):
        if not isinstance(n, dict):
            errs.append(f"nodes[{i}]: must be an object")
            continue
        nid = n.get("id")
        if not nid or not isinstance(nid, str):
            errs.append(f"nodes[{i}]: missing string 'id'")
            continue
        if nid in ids:
            errs.append(f"nodes[{i}]: duplicate id {nid!r}")
        ids.add(nid)

    edges = ir.get("edges", [])
    if not isinstance(edges, list):
        errs.append("edges: must be an array")
        edges = []
    for i, e in enumerate(edges):
        if not isinstance(e, dict):
            errs.append(f"edges[{i}]: must be an object")
            continue
        src, dst = e.get("from"), e.get("to")
        if src not in ids:
            errs.append(f"edges[{i}]: 'from' references unknown node {src!r}")
        if dst not in ids:
            errs.append(f"edges[{i}]: 'to' references unknown node {dst!r}")

    # Group membership references must resolve.
    group_ids = set()
    for i, g in enumerate(ir.get("groups", []) or []):
        if not isinstance(g, dict) or not g.get("id"):
            errs.append(f"groups[{i}]: must be an object with an 'id'")
            continue
        group_ids.add(g["id"])
    for i, n in enumerate(nodes):
        if isinstance(n, dict) and n.get("group") and n["group"] not in group_ids:
            errs.append(
                f"nodes[{i}] ({n.get('id')}): group {n['group']!r} not declared in 'groups'"
            )

    if errs:
        raise IRError("Invalid IR:\n  - " + "\n  - ".join(errs))


# ─── Layout: layered graph ───────────────────────────────────────────────────

NODE_W = 168
NODE_H = 56
GAP_MAIN = 96   # gap between ranks
GAP_CROSS = 40  # gap between nodes within a rank
PAD = 48
GROUP_PAD = 22


def _ranks(nodes, edges):
    """Longest-path rank assignment (topological). Cycles fall back gracefully."""
    ids = [n["id"] for n in nodes]
    succ = {i: [] for i in ids}
    indeg = {i: 0 for i in ids}
    for e in edges:
        succ[e["from"]].append(e["to"])
        indeg[e["to"]] += 1

    rank = {i: 0 for i in ids}
    # Kahn's algorithm; on a cycle, remaining nodes keep rank 0 (still drawn).
    from collections import deque

    q = deque([i for i in ids if indeg[i] == 0])
    seen = set()
    while q:
        u = q.popleft()
        seen.add(u)
        for v in succ[u]:
            rank[v] = max(rank[v], rank[u] + 1)
            indeg[v] -= 1
            if indeg[v] == 0:
                q.append(v)
    return rank


def layout_layered(ir):
    nodes = ir["nodes"]
    edges = ir.get("edges", [])
    direction = ir.get("direction") or ("LR" if ir["type"] == "architecture" else "TB")
    rank = _ranks(nodes, edges)

    # Bucket nodes by rank, preserving declaration order for stable layout.
    buckets = {}
    for n in nodes:
        buckets.setdefault(rank[n["id"]], []).append(n)
    max_rank = max(rank.values()) if rank else 0

    pos = {}
    widest = max((len(b) for b in buckets.values()), default=1)
    for r in range(max_rank + 1):
        col = buckets.get(r, [])
        # Center each rank against the widest rank.
        offset = (widest - len(col)) / 2.0
        for j, n in enumerate(col):
            lane = offset + j
            if direction == "LR":
                x = PAD + r * (NODE_W + GAP_MAIN)
                y = PAD + lane * (NODE_H + GAP_CROSS)
            else:  # TB
                x = PAD + lane * (NODE_W + GAP_CROSS)
                y = PAD + r * (NODE_H + GAP_MAIN)
            pos[n["id"]] = (x, y)

    return pos, direction


# ─── Layout: sequence (lifelines) ────────────────────────────────────────────

LIFELINE_GAP = 200
MSG_GAP = 64
HEAD_Y = PAD
LIFELINE_TOP = HEAD_Y + NODE_H + 24


def layout_sequence(ir):
    nodes = ir["nodes"]
    edges = ir.get("edges", [])
    x_of = {}
    for i, n in enumerate(nodes):
        x_of[n["id"]] = PAD + NODE_W / 2 + i * LIFELINE_GAP
    total_h = LIFELINE_TOP + (len(edges) + 1) * MSG_GAP + PAD
    return x_of, total_h


# ─── SVG rendering ───────────────────────────────────────────────────────────

# Groups cycle through accent classes g0..g5 (styled in CSS for both themes).
GROUP_CLASSES = 6


def esc(s):
    return html.escape(str(s), quote=True)


def _wrap_label(label, limit=22):
    words = str(label).split()
    lines, cur = [], ""
    for w in words:
        if len(cur) + len(w) + 1 > limit and cur:
            lines.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    if cur:
        lines.append(cur)
    return lines[:3]


def _node_svg(n, x, y, cls):
    parts = []
    parts.append(
        f'<g class="node {cls}">'
        f'<rect x="{x:.1f}" y="{y:.1f}" rx="10" ry="10" '
        f'width="{NODE_W}" height="{NODE_H}"/>'
    )
    lines = _wrap_label(n.get("label", n["id"]))
    tech = n.get("tech")
    cy = y + NODE_H / 2 - (len(lines) - 1) * 8 + (6 if tech else 0)
    for k, ln in enumerate(lines):
        parts.append(
            f'<text class="node-label" x="{x + NODE_W / 2:.1f}" '
            f'y="{cy + k * 16:.1f}">{esc(ln)}</text>'
        )
    if tech:
        parts.append(
            f'<text class="node-tech" x="{x + NODE_W / 2:.1f}" '
            f'y="{y + NODE_H - 9:.1f}">{esc(tech)}</text>'
        )
    parts.append("</g>")
    return "".join(parts)


def _edge_path(x1, y1, x2, y2, direction):
    """Orthogonal-ish connector between node centers on facing edges."""
    if direction == "LR":
        sx, sy = x1 + NODE_W, y1 + NODE_H / 2
        ex, ey = x2, y2 + NODE_H / 2
        mx = (sx + ex) / 2
        return f"M{sx:.1f},{sy:.1f} C{mx:.1f},{sy:.1f} {mx:.1f},{ey:.1f} {ex:.1f},{ey:.1f}", (ex, ey)
    else:
        sx, sy = x1 + NODE_W / 2, y1 + NODE_H
        ex, ey = x2 + NODE_W / 2, y2
        my = (sy + ey) / 2
        return f"M{sx:.1f},{sy:.1f} C{sx:.1f},{my:.1f} {ex:.1f},{my:.1f} {ex:.1f},{ey:.1f}", (ex, ey)


def render_layered_svg(ir):
    pos, direction = layout_layered(ir)
    groups = {g["id"]: g for g in (ir.get("groups") or [])}
    group_order = list(groups.keys())

    body = []

    # Group boundary boxes (drawn first, behind nodes).
    for gi, gid in enumerate(group_order):
        members = [n["id"] for n in ir["nodes"] if n.get("group") == gid]
        if not members:
            continue
        xs = [pos[m][0] for m in members]
        ys = [pos[m][1] for m in members]
        gx = min(xs) - GROUP_PAD
        gy = min(ys) - GROUP_PAD - 16
        gw = (max(xs) + NODE_W + GROUP_PAD) - gx
        gh = (max(ys) + NODE_H + GROUP_PAD) - gy
        cls = f"g{gi % GROUP_CLASSES}"
        body.append(
            f'<g class="group {cls}">'
            f'<rect x="{gx:.1f}" y="{gy:.1f}" rx="14" ry="14" '
            f'width="{gw:.1f}" height="{gh:.1f}"/>'
            f'<text class="group-label" x="{gx + 14:.1f}" y="{gy + 20:.1f}">'
            f'{esc(groups[gid].get("label", gid))}</text></g>'
        )

    # Edges.
    for e in ir.get("edges", []):
        x1, y1 = pos[e["from"]]
        x2, y2 = pos[e["to"]]
        path, (ex, ey) = _edge_path(x1, y1, x2, y2, direction)
        dash = ' stroke-dasharray="6 5"' if e.get("style") == "dashed" else ""
        body.append(
            f'<path class="edge" d="{path}" marker-end="url(#arrow)"{dash}/>'
        )
        if e.get("label"):
            body.append(
                f'<text class="edge-label" x="{(x1 + x2) / 2 + NODE_W / 2:.1f}" '
                f'y="{(y1 + y2) / 2 + NODE_H / 2 - 6:.1f}">{esc(e["label"])}</text>'
            )

    # Nodes.
    for n in ir["nodes"]:
        x, y = pos[n["id"]]
        gid = n.get("group")
        cls = f"g{group_order.index(gid) % GROUP_CLASSES}" if gid in groups else "g-plain"
        body.append(_node_svg(n, x, y, cls))

    xs = [p[0] for p in pos.values()]
    ys = [p[1] for p in pos.values()]
    width = max(xs) + NODE_W + PAD
    height = max(ys) + NODE_H + PAD
    return "\n".join(body), width, height


def render_sequence_svg(ir):
    x_of, height = layout_sequence(ir)
    body = []
    width = PAD + len(ir["nodes"]) * LIFELINE_GAP

    # Lifelines + actor heads.
    for n in ir["nodes"]:
        cx = x_of[n["id"]]
        body.append(
            f'<line class="lifeline" x1="{cx:.1f}" y1="{LIFELINE_TOP:.1f}" '
            f'x2="{cx:.1f}" y2="{height - PAD:.1f}"/>'
        )
        x = cx - NODE_W / 2
        body.append(_node_svg(n, x, HEAD_Y, "g-plain"))

    # Messages, top to bottom in declaration order.
    y = LIFELINE_TOP + MSG_GAP
    for e in ir.get("edges", []):
        x1, x2 = x_of[e["from"]], x_of[e["to"]]
        dash = ' stroke-dasharray="6 5"' if e.get("style") == "dashed" else ""
        if x1 == x2:  # self-message
            body.append(
                f'<path class="edge" d="M{x1:.1f},{y:.1f} h40 v22 h-40" '
                f'marker-end="url(#arrow)"{dash}/>'
            )
            lx, anchor = x1 + 48, "start"
        else:
            body.append(
                f'<line class="edge" x1="{x1:.1f}" y1="{y:.1f}" '
                f'x2="{x2:.1f}" y2="{y:.1f}" marker-end="url(#arrow)"{dash}/>'
            )
            lx, anchor = (x1 + x2) / 2, "middle"
        if e.get("label"):
            body.append(
                f'<text class="edge-label" text-anchor="{anchor}" '
                f'x="{lx:.1f}" y="{y - 8:.1f}">{esc(e["label"])}</text>'
            )
        y += MSG_GAP
    return "\n".join(body), width, height


# ─── HTML wrapper ────────────────────────────────────────────────────────────

CSS = """
:root{
  --bg:#f7f8fa; --panel:#ffffff; --ink:#1c2333; --muted:#5b6478;
  --edge:#7a8399; --node-stroke:#c3cbdb; --node-fill:#ffffff; --lifeline:#c3cbdb;
  --g0:#3b82f6; --g1:#10b981; --g2:#f59e0b; --g3:#ef4444; --g4:#8b5cf6; --g5:#06b6d4;
}
:root[data-theme="dark"]{
  --bg:#0f1420; --panel:#161c2b; --ink:#e7ecf5; --muted:#93a0b8;
  --edge:#6b7690; --node-stroke:#33405c; --node-fill:#1c2437; --lifeline:#33405c;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --bg:#0f1420; --panel:#161c2b; --ink:#e7ecf5; --muted:#93a0b8;
    --edge:#6b7690; --node-stroke:#33405c; --node-fill:#1c2437; --lifeline:#33405c;
  }
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
header{display:flex;align-items:center;gap:12px;padding:16px 22px;
  border-bottom:1px solid var(--node-stroke)}
header h1{font-size:16px;font-weight:600;margin:0;flex:1}
header .kind{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.08em}
button{font:inherit;font-size:13px;cursor:pointer;color:var(--ink);
  background:var(--panel);border:1px solid var(--node-stroke);
  border-radius:8px;padding:6px 12px}
button:hover{border-color:var(--edge)}
main{padding:22px;overflow:auto}
.wrap{background:var(--panel);border:1px solid var(--node-stroke);
  border-radius:14px;padding:8px;display:inline-block;max-width:100%;overflow:auto}
svg{display:block;max-width:100%;height:auto}
.node rect{fill:var(--node-fill);stroke:var(--node-stroke);stroke-width:1.5}
.node-label{fill:var(--ink);font-size:13px;font-weight:600;text-anchor:middle;dominant-baseline:middle}
.node-tech{fill:var(--muted);font-size:10.5px;font-family:ui-monospace,monospace;text-anchor:middle}
.edge{fill:none;stroke:var(--edge);stroke-width:1.6}
.edge-label{fill:var(--muted);font-size:11px;text-anchor:middle}
.lifeline{stroke:var(--lifeline);stroke-width:1.4;stroke-dasharray:3 5}
.group rect{fill:none;stroke-width:1.4;stroke-dasharray:5 5;opacity:.55}
.group-label{font-size:11px;font-weight:600;letter-spacing:.03em}
.node.g0 rect{stroke:var(--g0)} .node.g1 rect{stroke:var(--g1)}
.node.g2 rect{stroke:var(--g2)} .node.g3 rect{stroke:var(--g3)}
.node.g4 rect{stroke:var(--g4)} .node.g5 rect{stroke:var(--g5)}
.group.g0 rect{stroke:var(--g0)} .group.g0 .group-label{fill:var(--g0)}
.group.g1 rect{stroke:var(--g1)} .group.g1 .group-label{fill:var(--g1)}
.group.g2 rect{stroke:var(--g2)} .group.g2 .group-label{fill:var(--g2)}
.group.g3 rect{stroke:var(--g3)} .group.g3 .group-label{fill:var(--g3)}
.group.g4 rect{stroke:var(--g4)} .group.g4 .group-label{fill:var(--g4)}
.group.g5 rect{stroke:var(--g5)} .group.g5 .group-label{fill:var(--g5)}
"""

JS = """
const root=document.documentElement;
function preferred(){return matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light'}
root.dataset.theme=localStorage.getItem('archviz-theme')||preferred();
function toggle(){const t=root.dataset.theme==='dark'?'light':'dark';
  root.dataset.theme=t;localStorage.setItem('archviz-theme',t)}
function exportPNG(scale){
  const svg=document.querySelector('svg');
  const xml=new XMLSerializer().serializeToString(svg);
  const css=getComputedStyle(root);
  const bg=css.getPropertyValue('--panel').trim()||'#fff';
  const w=svg.viewBox.baseVal.width,h=svg.viewBox.baseVal.height;
  const img=new Image();
  img.onload=function(){
    const c=document.createElement('canvas');
    c.width=w*scale;c.height=h*scale;
    const ctx=c.getContext('2d');ctx.fillStyle=bg;ctx.fillRect(0,0,c.width,c.height);
    ctx.setTransform(scale,0,0,scale,0,0);ctx.drawImage(img,0,0);
    const a=document.createElement('a');
    a.download=(document.title||'diagram')+'.png';a.href=c.toDataURL('image/png');a.click();
  };
  img.src='data:image/svg+xml;base64,'+btoa(unescape(encodeURIComponent(xml)));
}
addEventListener('keydown',e=>{
  if(e.key==='t'||e.key==='T')toggle();
  if(e.key==='e'||e.key==='E')exportPNG(2);
});
"""


def wrap_html(title, dtype, svg_body, width, height):
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title>
<style>{CSS}</style>
</head>
<body>
<header>
  <span class="kind">{esc(dtype)}</span>
  <h1>{esc(title)}</h1>
  <button onclick="toggle()" title="Toggle theme (T)">◐ Theme</button>
  <button onclick="exportPNG(2)" title="Export PNG @2x (E)">⬇ PNG 2×</button>
  <button onclick="exportPNG(4)" title="Export PNG @4x">⬇ PNG 4×</button>
</header>
<main>
  <div class="wrap">
  <svg viewBox="0 0 {width:.0f} {height:.0f}" width="{width:.0f}" height="{height:.0f}"
       xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{esc(title)}">
    <defs>
      <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7"
              markerHeight="7" orient="auto-start-reverse">
        <path d="M0,0 L10,5 L0,10 z" fill="var(--edge)"/>
      </marker>
    </defs>
{svg_body}
  </svg>
  </div>
</main>
<script>{JS}</script>
</body>
</html>
"""


# ─── Post-render artifact check ──────────────────────────────────────────────


def artifact_check(width, height):
    """Catch degenerate layouts (archify's post-render verification step)."""
    warnings = []
    if width <= 0 or height <= 0:
        warnings.append("computed canvas has non-positive dimensions")
    if width > 20000 or height > 20000:
        warnings.append(
            f"canvas is very large ({width:.0f}×{height:.0f}px) — "
            "consider splitting into multiple diagrams"
        )
    return warnings


# ─── Main ────────────────────────────────────────────────────────────────────


def main(argv=None):
    ap = argparse.ArgumentParser(description="Validate + render a diagram IR to HTML.")
    ap.add_argument("ir", help="path to the diagram IR JSON file")
    ap.add_argument("-o", "--out", help="output HTML path (default: <ir>.html)")
    ap.add_argument("--check", action="store_true", help="validate only; no render")
    args = ap.parse_args(argv)

    try:
        with open(args.ir, encoding="utf-8") as f:
            ir = json.load(f)
    except FileNotFoundError:
        print(f"error: no such file: {args.ir}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"error: {args.ir} is not valid JSON: {e}", file=sys.stderr)
        return 2

    try:
        validate(ir)
    except IRError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    if args.check:
        print(f"OK: valid {ir['type']} IR ({len(ir['nodes'])} nodes, "
              f"{len(ir.get('edges', []))} edges)")
        return 0

    title = ir.get("title", "Diagram")
    if ir["type"] == "sequence":
        body, width, height = render_sequence_svg(ir)
    else:
        body, width, height = render_layered_svg(ir)

    for w in artifact_check(width, height):
        print(f"warning: {w}", file=sys.stderr)

    out = args.out or (args.ir.rsplit(".", 1)[0] + ".html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(wrap_html(title, ir["type"], body, width, height))
    print(f"rendered {out} ({width:.0f}×{height:.0f}px, {ir['type']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
