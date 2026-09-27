#!/usr/bin/env python3
"""Scoreboard: plugin vs native, checked against bench/goal.json.

    report.py <work-dir> [<work-dir> ...] [--md out.md]

Reads every <work>/<task>/<arm>-r<rep>/run.json, averages reps, and compares
arms per task, per tier, and suite-wide. Ratios are plugin/native; quality delta
is plugin minus native (hidden-test pass rate, 0-1).
"""
import glob, json, os, statistics, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def load(dirs):
    runs = []
    for d in dirs:
        for f in glob.glob(os.path.join(d, "*", "*-r*", "run.json")):
            runs.append(json.load(open(f)))
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

    lines = ["| Task | Tier | Arm | Reps | Quality | Cost | Wall | Turns | Commits (gated) |",
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
            gated = "" if arm == "native" else " (%s)" % "/".join(str(r["gated_commits"]) for r in rs)
            lines.append("| %s | %s | %s | %d | %.0f%% | $%.2f | %.0fs | %.0f | %s%s |" % (
                t, tier, arm, len(rs), 100 * q, c, w, turns, "/".join(str(r["commits"]) for r in rs), gated))
            agg.setdefault(t, {})[arm] = {"tier": tier, "q": q, "c": c, "w": w, "n": len(rs),
                                          "ungated": sum((r["commits"] - (r["gated_commits"] or 0)) for r in rs) if arm == "plugin" else 0}

    def compare(task_names):
        pairs = [agg[t] for t in task_names if "native" in agg[t] and "plugin" in agg[t]]
        if not pairs:
            return None
        return {"dq": mean(p["plugin"]["q"] - p["native"]["q"] for p in pairs),
                "cr": sum(p["plugin"]["c"] for p in pairs) / max(1e-9, sum(p["native"]["c"] for p in pairs)),
                "tr": sum(p["plugin"]["w"] for p in pairs) / max(1e-9, sum(p["native"]["w"] for p in pairs)),
                "n": min(min(p["plugin"]["n"], p["native"]["n"]) for p in pairs), "tasks": len(pairs)}

    lines += ["", "| Scope | Quality Δ (target) | Cost ratio (target) | Time ratio (target) | Min reps |",
              "|---|---|---|---|---|"]
    all_ok = True
    scopes = [(tier, [t for t in agg if agg[t][next(iter(agg[t]))]["tier"] == tier], goal["tiers"][tier]) for tier in ("small", "medium", "complex")]
    scopes.append(("suite", list(agg), goal["suite"]))
    for name, ts, g in scopes:
        cmp = compare(ts)
        if not cmp:
            continue
        okq, okc, okt = cmp["dq"] >= g["quality_delta_min"], cmp["cr"] <= g["cost_ratio_max"], cmp["tr"] <= g["time_ratio_max"]
        all_ok &= okq and okc and okt
        lines.append("| %s | %+.0f pts %s (≥ %+.0f) | %s %s (≤ %.1f) | %s %s (≤ %.1f) | %d |" % (
            name, 100 * cmp["dq"], verdict(okq), 100 * g["quality_delta_min"], fmt_ratio(cmp["cr"]), verdict(okc),
            g["cost_ratio_max"], fmt_ratio(cmp["tr"]), verdict(okt), g["time_ratio_max"], cmp["n"]))
    ungated = sum(a["plugin"]["ungated"] for a in agg.values() if "plugin" in a)
    ok_int = ungated <= goal["integrity"]["plugin_unproven_commits_max"]
    all_ok &= ok_int
    reps = min((a[arm]["n"] for a in agg.values() for arm in a), default=0)
    lines += ["", "Integrity: plugin commits that bypassed the gate: %d %s" % (ungated, verdict(ok_int)),
              "", "**Goal %s**%s" % ("met" if all_ok else "not met",
                                      "" if reps >= goal["min_reps_to_claim"] else
                                      " — directional only: %d rep(s), claims need %d." % (reps, goal["min_reps_to_claim"]))]
    text = "\n".join(lines)
    print(text)
    if md_out:
        open(md_out, "w").write(text + "\n")


if __name__ == "__main__":
    main()
