#!/usr/bin/env python3
"""Scoreboard: plugin vs native, checked against bench/goal.json.

    report.py <work-dir> [<work-dir> ...] [--md out.md]

Reads every <work>/<task>/<arm>-r<rep>/run.json, averages reps, and compares
arms per task, per tier, and suite-wide. Ratios are plugin/native; quality delta
is plugin minus native (hidden-test pass rate, 0-1).
"""
import glob, json, os, statistics, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def gating(rdir):
    """(ungated commits made while a feature was open, commits made after the
    last close). A commit with no active feature is outside the loop by design:
    the gate is a no-op then, so it is reported, not counted as a bypass."""
    import re, subprocess
    proj = os.path.join(rdir, "project")
    git = lambda *a: subprocess.run(["git", "-C", proj] + list(a), capture_output=True, text=True).stdout
    heads = set()
    for f in glob.glob(os.path.join(proj, ".coding-agent", "*", "evidence.jsonl")):
        for l in open(f):
            if l.strip():
                e = json.loads(l)
                if e.get("kind") == "run" and e.get("tier") == "commit" and e.get("exit") == 0:
                    heads.add(e.get("head"))
    closes = []
    prod = os.path.join(proj, ".coding-agent", "product.md")
    if os.path.exists(prod):
        closes = re.findall(r"^### .+ — \w+ @(\S+)", open(prod).read(), re.M)
    import datetime
    last_close = max((datetime.datetime.strptime(c, "%Y-%m-%dT%H:%M:%SZ").timestamp() for c in closes), default=None)
    root = git("rev-list", "--max-parents=0", "HEAD").split()[-1]
    inside = outside = 0
    for line in git("log", "--format=%H %P %ct").splitlines():
        parts = line.split()
        if parts[0] == root or parts[1] in heads:
            continue
        if last_close is not None and int(parts[-1]) > last_close:
            outside += 1
        else:
            inside += 1
    return inside, outside


def load(dirs):
    runs = []
    for d in dirs:
        for f in glob.glob(os.path.join(d, "*", "*-r*", "run.json")):
            r = json.load(open(f))
            if r["arm"] == "plugin":
                r["ungated_inside"], r["after_close"] = gating(os.path.dirname(f))
            runs.append(r)
    return runs


def mean(xs):
    xs = [x for x in xs if x is not None]
    return statistics.mean(xs) if xs else None


def fmt_ratio(x):
    return "—" if x is None else "%.2f×" % x


def verdict(ok):
    return "—" if ok is None else ("✅" if ok else "❌")


def main():
    args = sys.argv[1:]
    md_out = None
    if "--md" in args:
        i = args.index("--md")
        md_out = args[i + 1]
        del args[i:i + 2]
    goal = json.load(open(os.path.join(HERE, "goal.json")))
    runs = load(args)
    if not runs:
        sys.exit("no run.json found under: %s" % " ".join(args))

    by = {}
    for r in runs:
        by.setdefault((r["task"], r["arm"]), []).append(r)
    tasks = sorted({t for t, _ in by}, key=lambda t: ({"small": 0, "medium": 1, "complex": 2}.get(by[(t, next(a for tt, a in by if tt == t))][0]["tier"], 9), t))

    lines = ["| Task | Tier | Arm | Reps | Quality | Cost | Wall | Turns | Commits (plugin: ungated) |",
             "|---|---|---|---|---|---|---|---|---|"]
    agg = {}
    for t in tasks:
        for arm in ("native", "plugin"):
            rs = by.get((t, arm))
            if not rs:
                continue
            tier = rs[0]["tier"]
            q, c, w = mean(r["quality"] for r in rs), mean(r["cost_usd"] for r in rs), mean(r["wall_s"] for r in rs)
            turns = mean(r["turns"] for r in rs)
            gated = "" if arm == "native" else " (%s)" % "/".join(
                "%d ungated%s" % (r["ungated_inside"], ", %d after close" % r["after_close"] if r["after_close"] else "") for r in rs)
            lines.append("| %s | %s | %s | %d | %.0f%% | $%.2f | %.0fs | %.0f | %s%s |" % (
                t, tier, arm, len(rs), 100 * q, c, w, turns, "/".join(str(r["commits"]) for r in rs), gated))
            agg.setdefault(t, {})[arm] = {"tier": tier, "q": q, "c": c, "w": w, "n": len(rs),
                                          "ungated": sum(r["ungated_inside"] for r in rs) if arm == "plugin" else 0}

    def compare(task_names):
        pairs = [agg[t] for t in task_names if "native" in agg[t] and "plugin" in agg[t]]
        if not pairs:
            return None
        return {"dq": mean(p["plugin"]["q"] - p["native"]["q"] for p in pairs),
                "cr": sum(p["plugin"]["c"] for p in pairs) / max(1e-9, sum(p["native"]["c"] for p in pairs)),
                "tr": sum(p["plugin"]["w"] for p in pairs) / max(1e-9, sum(p["native"]["w"] for p in pairs)),
                "n": min(min(p["plugin"]["n"], p["native"]["n"]) for p in pairs), "tasks": len(pairs)}

    lines += ["", "| Pillar | Tasks | Quality Δ | Cost ratio | Time ratio | Target | Met |",
              "|---|---|---|---|---|---|---|"]
    by_pillar = {}
    for t in agg:
        pil = next(r["pillar"] for r in runs if r["task"] == t and r.get("pillar")) if any(r.get("pillar") for r in runs if r["task"] == t) else "correctness"
        by_pillar.setdefault(pil, []).append(t)
    results = {}
    for pil in ("continuity", "standards", "correctness"):
        cmp = compare(by_pillar.get(pil, []))
        if not cmp:
            continue
        g = goal["pillars"].get(pil) or goal["floors"].get(pil)
        ok = cmp["dq"] >= g["quality_delta_min"]
        results[pil] = ok
        lines.append("| %s | %d | %+.0f pts | %s | %s | Δ ≥ %+.0f pts | %s |" % (
            pil, cmp["tasks"], 100 * cmp["dq"], fmt_ratio(cmp["cr"]), fmt_ratio(cmp["tr"]),
            100 * g["quality_delta_min"], verdict(ok)))
    suite = compare(list(agg))
    all_ok = True
    if suite:
        sp = suite["tr"] <= goal["pillars"]["speed"]["time_ratio_max"]
        co = suite["cr"] <= goal["floors"]["cost"]["cost_ratio_max"]
        results["speed"] = sp
        lines.append("| speed (suite) | %d | %+.0f pts | %s | %s | time ≤ %.1f× | %s |" % (
            suite["tasks"], 100 * suite["dq"], fmt_ratio(suite["cr"]), fmt_ratio(suite["tr"]),
            goal["pillars"]["speed"]["time_ratio_max"], verdict(sp)))
        lines.append("| cost floor (suite) | %d | | %s | | cost ≤ %.1f× | %s |" % (
            suite["tasks"], fmt_ratio(suite["cr"]), goal["floors"]["cost"]["cost_ratio_max"], verdict(co)))
        missing = [p for p in ("continuity", "standards") if p not in results]
        wins = [p for p in ("continuity", "standards") if results.get(p)]
        floor = results.get("correctness", True)
        worth = bool(wins) and floor
        lines += ["", "**Verdict: %s** — pillars won: %s; correctness floor %s; speed %s." % (
            ("incomplete (not measured: %s)" % ", ".join(missing)) if missing else
            "worth running" if worth else ("retire" if not wins and not sp else "not yet worth running"),
            ", ".join(wins) or "none", "held" if floor else "broken", "won" if sp else "lost")]
        all_ok = worth
    ungated = sum(a["plugin"]["ungated"] for a in agg.values() if "plugin" in a)
    ok_int = ungated <= goal["integrity"]["plugin_unproven_commits_max"]
    all_ok &= ok_int
    reps = min((a[arm]["n"] for a in agg.values() for arm in a), default=0)
    lines += ["", "Integrity: plugin commits made inside a feature without passing the gate: %d %s" % (ungated, verdict(ok_int)),
              "", "**Goal %s**%s" % ("met" if all_ok else "not met",
                                      "" if reps >= goal["min_reps_to_claim"] else
                                      " — directional only: %d rep(s), claims need %d." % (reps, goal["min_reps_to_claim"]))]
    text = "\n".join(lines)
    print(text)
    if md_out:
        open(md_out, "w").write(text + "\n")


if __name__ == "__main__":
    main()
