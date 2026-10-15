#!/usr/bin/env python3
"""Score a project against a task's hidden acceptance tests.

    score.py <task_dir> <project_dir> <phase_file>   -> JSON on stdout

The project is copied (without .git / runtime state) to a scratch dir so the
hidden tests can never leave artifacts behind, and every hidden suite listed for
the phase in task.json runs there. A test counts as passed only if it ran and
succeeded; a class whose setup fails (e.g. the server never starts) scores zero
for every test in it.
"""
import json, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

RUNNER = r'''
import json, sys, unittest
mods = sys.argv[1:]
loader = unittest.TestLoader()
out = {}
for m in mods:
    try:
        suite = loader.loadTestsFromName(m)
    except Exception as e:  # import failure: the whole suite fails
        out[m] = {"passed": 0, "total": None, "import_error": repr(e)[:300]}
        continue
    total = suite.countTestCases()
    class R(unittest.TextTestResult):
        ok = []
        def addSuccess(self, test):
            super().addSuccess(test); R.ok.append(test.id())
    R.ok = []
    res = unittest.TextTestRunner(stream=open("/dev/null", "w"), resultclass=R).run(suite)
    fails = [t.id() for t, _ in res.failures + res.errors]
    out[m] = {"passed": len(R.ok), "total": total, "failed": fails[:40], "ok": R.ok}
print("@@RESULT@@" + json.dumps(out))
'''


TAGS = ("conv", "dec", "defer", "resume", "feat")


def test_names(path):
    import ast
    tree = ast.parse(open(path).read())
    return [n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name.startswith("test")]


def count_tests(path):
    return len(test_names(path))


def tag_of(name):
    """test_<tag>_... names the behaviour a test measures (see a task's hidden/*test.py)."""
    t = name.split("_")[1] if name.count("_") >= 2 else ""
    return t if t in TAGS else None


def main():
    task_dir, project, phase = sys.argv[1:4]
    task = json.load(open(os.path.join(task_dir, "task.json")))
    if phase not in task["hidden"]:  # e.g. a deliberately interrupted phase
        print(json.dumps({"phase": phase, "passed": 0, "total": 0, "rate": None, "suites": {}, "error": None, "scored": False}))
        return
    suites = task["hidden"][phase]
    scratch = tempfile.mkdtemp(prefix="bench-score-")
    app = os.path.join(scratch, "app")
    shutil.copytree(project, app, ignore=shutil.ignore_patterns(".git", ".coding-agent", "__pycache__", "*.db", "*.db-*"))
    tests = os.path.join(scratch, "tests")
    os.makedirs(tests)
    for f in os.listdir(os.path.join(task_dir, "hidden")):
        if f.endswith(".py"):
            shutil.copy(os.path.join(task_dir, "hidden", f), tests)
    shutil.copy(os.path.join(HERE, "lib", "apptest.py"), tests)
    with open(os.path.join(tests, "_runner.py"), "w") as fh:
        fh.write(RUNNER)
    env = dict(os.environ, APP_DIR=app, PYTHONDONTWRITEBYTECODE="1")
    mods = [s[:-3] for s in suites]
    try:
        proc = subprocess.run([sys.executable, "-W", "ignore", "_runner.py"] + mods, cwd=tests, env=env,
                              capture_output=True, text=True, timeout=900)
        raw = proc.stdout.split("@@RESULT@@")[-1] if "@@RESULT@@" in proc.stdout else None
        detail = json.loads(raw) if raw else {}
        err = None if raw else (proc.stderr[-600:] or "runner produced no result")
    except subprocess.TimeoutExpired:
        detail, err = {}, "scoring timed out"
    passed = total = 0
    by_tag = {}
    for s in suites:
        m = s[:-3]
        d = detail.get(m) or {"passed": 0, "total": None}
        # The hidden suite is fixed, so its size is the denominator. An import
        # failure makes unittest report a single synthetic test instead.
        n = count_tests(os.path.join(task_dir, "hidden", s))
        d["total"] = n
        d["passed"] = min(d["passed"], n)
        ok_names = [i.rsplit(".", 1)[-1] for i in d.pop("ok", None) or []]
        for name in test_names(os.path.join(task_dir, "hidden", s)):
            t = tag_of(name)
            if t:
                by_tag.setdefault(t, [0, 0])[1] += 1
        for name in ok_names:
            t = tag_of(name)
            if t:
                by_tag[t][0] += 1
        detail[m] = d
        passed += d["passed"]
        total += n
    shutil.rmtree(scratch, ignore_errors=True)
    print(json.dumps({"phase": phase, "passed": passed, "total": total,
                      "rate": round(passed / total, 4) if total else 0.0, "suites": detail, "error": err,
                      "by_tag": by_tag}))


if __name__ == "__main__":
    main()
