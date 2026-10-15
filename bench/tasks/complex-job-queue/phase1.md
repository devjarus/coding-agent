Build a durable **job queue** library as a Python package named `jobq` at the root of this empty repo (so `from jobq import ...` works from the repo root). Python 3 standard library only; state lives in one SQLite file. Several worker **processes** will use the same database file at the same time.

```python
from jobq import Queue, LeaseLost, NotFound
q = Queue(db_path, clock=time.time)   # clock() returns epoch seconds; tests inject a fake clock
```

| Call | Behavior |
|---|---|
| `q.enqueue(kind, payload, *, priority=0, delay=0, dedupe_key=None, max_attempts=3)` → `job_id` (str) | `payload` is any JSON-serializable value. The job becomes runnable `delay` seconds from now. If `dedupe_key` is given and a job with that key is still queued or running, return that job's id instead of creating a new one. |
| `q.lease(worker_id, kinds=None, lease_seconds=30)` → job dict or `None` | Picks the runnable job with the **highest priority**, then the **earliest runnable time**, then the **earliest enqueued**. `kinds` (list) restricts which kinds to take. Returns `{"id", "kind", "payload", "attempt"}` where `attempt` is 1 on the first lease, 2 on the second, … A leased job is invisible to other `lease` calls until its lease expires. **Concurrent `lease` calls from many processes must never hand the same job to two workers.** |
| `q.heartbeat(job_id, worker_id, lease_seconds=30)` | Extends the lease to `lease_seconds` from now. |
| `q.complete(job_id, worker_id, result=None)` | Marks the job done. |
| `q.fail(job_id, worker_id, error)` | Records a failed attempt (see retries). |
| `q.get(job_id)` → dict | `{"id", "kind", "payload", "status", "attempts", "result", "last_error"}` with `status` one of `queued`, `running`, `done`, `dead`. Unknown id → `NotFound`. |
| `q.dead()` → list | Ids of dead jobs, oldest first. |
| `q.requeue(job_id)` | Moves a dead job back to `queued` with attempts reset to 0 and runnable now. A job that isn't dead → `ValueError`. |
| `q.stats()` → dict | `{"queued", "running", "done", "dead"}` counts. |

`heartbeat`, `complete` and `fail` raise `LeaseLost` if the caller is not the current lease holder or the lease has already expired.

**Retries.** A failed attempt (a `fail` call, or a lease that expired without `complete`) sends the job back to the queue if it has attempts left, runnable after a backoff of `10 * 2**(attempt - 1)` seconds (10 s after attempt 1, 20 s after attempt 2, …). For an expired lease, count the backoff from the moment the lease expired, and record `last_error` as `"lease expired"`. When the attempt that failed was attempt number `max_attempts`, the job becomes `dead` instead. Expiry is evaluated against `clock()` whenever the queue is used.

**CLI.** `python3 -m jobq stats <db_path>` prints the `stats()` dict as JSON.

Include automated tests.
