"""Reference job queue. Used only to validate the hidden tests."""
import json, sqlite3, time, uuid


class LeaseLost(Exception):
    pass


class NotFound(Exception):
    pass


class Queue:
    def __init__(self, db_path, clock=time.time):
        self.clock = clock
        self.db = sqlite3.connect(db_path, timeout=30, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.execute("pragma journal_mode=wal")
        self.db.execute("""create table if not exists jobs(
            seq integer primary key autoincrement, id text unique, kind text, payload text, priority int,
            runnable_at real, dedupe_key text, max_attempts int, attempts int default 0, status text,
            worker text, lease_expires real, result text, last_error text)""")

    def _tx(self):
        self.db.execute("begin immediate")

    def _expire(self, now):
        for r in self.db.execute("select * from jobs where status='running' and lease_expires<=?", (now,)).fetchall():
            self._retry(r, r["lease_expires"], "lease expired")

    def _retry(self, r, at, err):
        if r["attempts"] >= r["max_attempts"]:
            self.db.execute("update jobs set status='dead', worker=null, last_error=? where id=?", (err, r["id"]))
        else:
            self.db.execute("update jobs set status='queued', worker=null, last_error=?, runnable_at=? where id=?",
                            (err, at + 10 * 2 ** (r["attempts"] - 1), r["id"]))

    def _run(self, fn):
        self._tx()
        try:
            self._expire(self.clock())
            out = fn()
            self.db.execute("commit")
            return out
        except BaseException:
            self.db.execute("rollback")
            raise

    def enqueue(self, kind, payload, *, priority=0, delay=0, dedupe_key=None, max_attempts=3):
        def go():
            if dedupe_key is not None:
                r = self.db.execute("select id from jobs where dedupe_key=? and status in ('queued','running')", (dedupe_key,)).fetchone()
                if r:
                    return r[0]
            jid = uuid.uuid4().hex
            self.db.execute("insert into jobs(id,kind,payload,priority,runnable_at,dedupe_key,max_attempts,status) values(?,?,?,?,?,?,?,'queued')",
                            (jid, kind, json.dumps(payload), priority, self.clock() + delay, dedupe_key, max_attempts))
            return jid
        return self._run(go)

    def lease(self, worker_id, kinds=None, lease_seconds=30):
        def go():
            now = self.clock()
            q, args = "select * from jobs where status='queued' and runnable_at<=?", [now]
            if kinds:
                q += " and kind in (%s)" % ",".join("?" * len(kinds))
                args += list(kinds)
            r = self.db.execute(q + " order by priority desc, runnable_at asc, seq asc limit 1", args).fetchone()
            if not r:
                return None
            self.db.execute("update jobs set status='running', worker=?, attempts=attempts+1, lease_expires=? where id=?",
                            (worker_id, now + lease_seconds, r["id"]))
            return {"id": r["id"], "kind": r["kind"], "payload": json.loads(r["payload"]), "attempt": r["attempts"] + 1}
        return self._run(go)

    def _held(self, job_id, worker_id):
        r = self.db.execute("select * from jobs where id=?", (job_id,)).fetchone()
        if not r:
            raise NotFound(job_id)
        if r["status"] != "running" or r["worker"] != worker_id:
            raise LeaseLost(job_id)
        return r

    def heartbeat(self, job_id, worker_id, lease_seconds=30):
        def go():
            self._held(job_id, worker_id)
            self.db.execute("update jobs set lease_expires=? where id=?", (self.clock() + lease_seconds, job_id))
        return self._run(go)

    def complete(self, job_id, worker_id, result=None):
        def go():
            self._held(job_id, worker_id)
            self.db.execute("update jobs set status='done', worker=null, result=? where id=?", (json.dumps(result), job_id))
        return self._run(go)

    def fail(self, job_id, worker_id, error):
        def go():
            r = self._held(job_id, worker_id)
            self._retry(r, self.clock(), error)
        return self._run(go)

    def get(self, job_id):
        def go():
            r = self.db.execute("select * from jobs where id=?", (job_id,)).fetchone()
            if not r:
                raise NotFound(job_id)
            return {"id": r["id"], "kind": r["kind"], "payload": json.loads(r["payload"]), "status": r["status"],
                    "attempts": r["attempts"], "result": json.loads(r["result"]) if r["result"] else None, "last_error": r["last_error"]}
        return self._run(go)

    def dead(self):
        return self._run(lambda: [r[0] for r in self.db.execute("select id from jobs where status='dead' order by seq")])

    def requeue(self, job_id):
        def go():
            r = self.db.execute("select status from jobs where id=?", (job_id,)).fetchone()
            if not r:
                raise NotFound(job_id)
            if r[0] != "dead":
                raise ValueError("job is not dead")
            self.db.execute("update jobs set status='queued', attempts=0, runnable_at=? where id=?", (self.clock(), job_id))
        return self._run(go)

    def stats(self):
        def go():
            d = {"queued": 0, "running": 0, "done": 0, "dead": 0}
            for s, n in self.db.execute("select status, count(*) from jobs group by status"):
                d[s] = n
            return d
        return self._run(go)
