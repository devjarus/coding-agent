#!/usr/bin/env python3
"""Re-score finished runs with the current hidden tests.

    rescore.py <work-dir> [<work-dir> ...]

Hidden suites grow when a stated requirement turns out to be untested; every
run must then be re-scored against the same suite, or the scoreboard compares
different yardsticks. For each phase, the state that phase delivered is the
phase snapshot if run.sh saved one, else the last commit made before that
phase's session ended (the mtime of <phase>.claude.json). Rows and run.json are
updated in place, and the old score is kept under "previous".
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def git(proj, *a):
    return subprocess.run(["git", "-C", proj] + list(a), capture_output=True, text=True).stdout.strip()


def phase_tree(rdir, proj, phase):
    snap = os.path.join(rdir, phase + ".snapshot")
    if os.path.isdir(snap):
        return snap, "snapshot"
    cutoff = os.path.getmtime(os.path.join(rdir, phase + ".claude.json")) + 2
    commits = git(proj, "log", "--format=%H %ct").splitlines()
    chosen = next((c.split()[0] for c in commits if int(c.split()[1]) <= cutoff), None)
    out = tempfile.mkdtemp(prefix="bench-rescore-")
    subprocess.run("git -C %s archive %s | tar -x -C %s" % (proj, chosen, out), shell=True, check=True)
    return out, "commit " + chosen[:8]


def main():
    for work in sys.argv[1:]:
        for rj in sorted(glob.glob(os.path.join(work, "*", "*-r*", "run.json"))):
            rdir = os.path.dirname(rj)
            run = json.load(open(rj))
            tdir = os.path.join(HERE, "tasks", run["task"])
            proj = os.path.join(rdir, "project")
            for i, row in enumerate(run["phases"]):
                ph = row["phase"]
                if not row.get("scored", True):
                    continue
                tree, source = phase_tree(rdir, proj, ph)
                s = json.loads(subprocess.run([sys.executable, os.path.join(HERE, "score.py"), tdir, tree, ph + ".md"],
                                              capture_output=True, text=True).stdout)
                if (s["passed"], s["total"]) != (row["passed"], row["total"]):
                    row.setdefault("previous", {"passed": row["passed"], "total": row["total"]})
                row.update(passed=s["passed"], total=s["total"], rate=s["rate"], scored_from=source, by_tag=s.get("by_tag"),
                           failed=[f for v in s["suites"].values() for f in (v.get("failed") or [])])
                json.dump(row, open(os.path.join(rdir, ph + ".row.json"), "w"))
                json.dump(s, open(os.path.join(rdir, ph + ".score.json"), "w"))
                run["phases"][i] = row
                print("%-24s %-7s %-7s %3d/%-3d  (%s)%s" % (run["task"], run["arm"], ph, s["passed"], s["total"], source,
                      "  failed: %s" % row["failed"] if row["failed"] else ""))
            sc = [p for p in run["phases"] if p.get("scored", True)]
            run["quality"] = round(sum(p["rate"] for p in sc) / len(sc), 4)
            run["by_tag_final"] = sc[-1].get("by_tag") if sc else None
            json.dump(run, open(rj, "w"), indent=2)


if __name__ == "__main__":
    main()
