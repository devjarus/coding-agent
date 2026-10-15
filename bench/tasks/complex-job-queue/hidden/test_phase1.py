"""Hidden acceptance tests — job queue."""
import json, os, subprocess, sys, tempfile, textwrap, unittest

APP = os.environ["APP_DIR"]
sys.path.insert(0, APP)
import jobq  # noqa: E402


class Clock:
    def __init__(self, t=1_000_000.0):
        self.t = t

    def __call__(self):
        return self.t

    def advance(self, s):
        self.t += s


class Base(unittest.TestCase):
    def setUp(self):
        self.db = os.path.join(tempfile.mkdtemp(prefix="bench-jq-"), "q.db")
        self.clock = Clock()
        self.q = jobq.Queue(self.db, clock=self.clock)


class Ordering(Base):
    def test_priority_then_runnable_then_fifo(self):
        a = self.q.enqueue("k", {"n": "a"})
        b = self.q.enqueue("k", {"n": "b"}, priority=5)
        self.clock.advance(1)
        c = self.q.enqueue("k", {"n": "c"}, priority=5)
        d = self.q.enqueue("k", {"n": "d"})
        got = [self.q.lease("w")["id"] for _ in range(4)]
        self.assertEqual(got, [b, c, a, d])
        self.assertIsNone(self.q.lease("w"))

    def test_delay(self):
        j = self.q.enqueue("k", 1, delay=60)
        self.assertIsNone(self.q.lease("w"))
        self.clock.advance(60)
        self.assertEqual(self.q.lease("w")["id"], j)

    def test_kinds_filter_and_payload(self):
        self.q.enqueue("email", {"to": "a@b"})
        s = self.q.enqueue("sms", [1, 2, 3])
        job = self.q.lease("w", kinds=["sms"])
        self.assertEqual((job["id"], job["kind"], job["payload"], job["attempt"]), (s, "sms", [1, 2, 3], 1))


class Dedupe(Base):
    def test_same_id_while_unfinished(self):
        a = self.q.enqueue("k", 1, dedupe_key="x")
        self.assertEqual(self.q.enqueue("k", 2, dedupe_key="x"), a)
        self.q.lease("w")
        self.assertEqual(self.q.enqueue("k", 3, dedupe_key="x"), a)   # running still dedupes
        self.q.complete(a, "w")
        self.assertNotEqual(self.q.enqueue("k", 4, dedupe_key="x"), a)
        self.assertEqual(self.q.stats()["queued"], 1)


class Leases(Base):
    def test_invisible_while_leased(self):
        self.q.enqueue("k", 1)
        self.assertIsNotNone(self.q.lease("w1"))
        self.assertIsNone(self.q.lease("w2"))

    def test_expiry_counts_as_failure_with_backoff(self):
        j = self.q.enqueue("k", 1)
        self.q.lease("w1", lease_seconds=30)
        self.clock.advance(31)                  # lease expired at +30; backoff 10 -> runnable at +40
        self.assertIsNone(self.q.lease("w2"))
        self.assertEqual(self.q.get(j)["last_error"], "lease expired")
        self.clock.advance(10)                  # +41
        job = self.q.lease("w2")
        self.assertEqual((job["id"], job["attempt"]), (j, 2))

    def test_wrong_worker_and_expired_lease(self):
        j = self.q.enqueue("k", 1)
        self.q.lease("w1", lease_seconds=30)
        with self.assertRaises(jobq.LeaseLost):
            self.q.complete(j, "w2")
        self.clock.advance(31)
        with self.assertRaises(jobq.LeaseLost):
            self.q.complete(j, "w1")

    def test_heartbeat_extends(self):
        j = self.q.enqueue("k", 1)
        self.q.lease("w1", lease_seconds=30)
        self.clock.advance(25)
        self.q.heartbeat(j, "w1", lease_seconds=30)
        self.clock.advance(25)                  # 50s after lease, 25s after heartbeat
        self.q.complete(j, "w1", result={"ok": True})
        g = self.q.get(j)
        self.assertEqual((g["status"], g["result"], g["attempts"]), ("done", {"ok": True}, 1))


class Retries(Base):
    def test_backoff_doubles_then_dead(self):
        j = self.q.enqueue("k", 1, max_attempts=3)
        self.q.fail(self.q.lease("w")["id"], "w", "boom1")
        self.clock.advance(9)
        self.assertIsNone(self.q.lease("w"))
        self.clock.advance(1)                   # 10s after attempt 1
        self.assertEqual(self.q.lease("w")["attempt"], 2)
        self.q.fail(j, "w", "boom2")
        self.clock.advance(19)
        self.assertIsNone(self.q.lease("w"))
        self.clock.advance(1)                   # 20s after attempt 2
        self.assertEqual(self.q.lease("w")["attempt"], 3)
        self.q.fail(j, "w", "boom3")
        g = self.q.get(j)
        self.assertEqual((g["status"], g["last_error"], g["attempts"]), ("dead", "boom3", 3))
        self.clock.advance(10_000)
        self.assertIsNone(self.q.lease("w"))
        self.assertEqual(self.q.dead(), [j])

    def test_requeue(self):
        j = self.q.enqueue("k", 1, max_attempts=1)
        self.q.fail(self.q.lease("w")["id"], "w", "x")
        with self.assertRaises(ValueError):
            self.q.requeue(self.q.enqueue("k", 2))
        self.q.requeue(j)
        g = self.q.get(j)
        self.assertEqual((g["status"], g["attempts"]), ("queued", 0))
        job = self.q.lease("w", kinds=["k"])
        self.assertEqual((job["id"], job["attempt"]), (j, 1))

    def test_expiry_on_last_attempt_is_dead(self):
        j = self.q.enqueue("k", 1, max_attempts=1)
        self.q.lease("w", lease_seconds=5)
        self.clock.advance(6)
        self.assertEqual(self.q.stats()["dead"], 1)
        self.assertEqual(self.q.get(j)["status"], "dead")

    def test_not_found(self):
        with self.assertRaises(jobq.NotFound):
            self.q.get("nope")


class Persistence(Base):
    def test_state_survives_and_cli(self):
        a = self.q.enqueue("k", 1)
        self.q.enqueue("k", 2)
        self.q.complete(self.q.lease("w")["id"], "w")
        again = jobq.Queue(self.db, clock=Clock(self.clock.t))
        self.assertEqual(again.get(a)["status"], "done")
        out = subprocess.run([sys.executable, "-m", "jobq", "stats", self.db], cwd=APP, capture_output=True, text=True, timeout=30)
        self.assertEqual(json.loads(out.stdout), {"queued": 1, "running": 0, "done": 1, "dead": 0})


WORKER = textwrap.dedent("""
    import json, sys, time
    sys.path.insert(0, sys.argv[1])
    import jobq
    q = jobq.Queue(sys.argv[2])
    got, empty = [], 0
    while empty < 3:
        job = q.lease(sys.argv[3], lease_seconds=300)
        if job is None:
            empty += 1
            time.sleep(0.05)
            continue
        empty = 0
        got.append(job["id"])
        q.complete(job["id"], sys.argv[3])
    print(json.dumps(got))
""")


class Concurrency(Base):
    def test_many_processes_never_share_a_job(self):
        q = jobq.Queue(self.db)                 # real clock for the multi-process run
        ids = {q.enqueue("k", i) for i in range(160)}
        script = os.path.join(os.path.dirname(self.db), "worker.py")
        with open(script, "w") as fh:
            fh.write(WORKER)
        procs = [subprocess.Popen([sys.executable, script, APP, self.db, "w%d" % i], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                 for i in range(8)]
        leased, errors = [], []
        for p in procs:
            out, err = p.communicate(timeout=240)
            if p.returncode != 0:
                errors.append(err[-300:])
                continue
            leased += json.loads(out.strip().splitlines()[-1])
        self.assertEqual(errors, [])
        self.assertEqual(len(leased), len(set(leased)), "a job was leased to two workers")
        self.assertEqual(set(leased), ids)
        self.assertEqual(q.stats()["done"], 160)


if __name__ == "__main__":
    unittest.main()
