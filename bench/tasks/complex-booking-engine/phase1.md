Build a seat **booking engine** as a Python package named `booking` at the root of this empty repo (so `from booking import ...` works from the repo root). Python 3 standard library only; persist state in SQLite.

```python
from booking import BookingSystem, SoldOut, HoldExpired, NotFound
bs = BookingSystem(db_path, clock=time.time)   # clock() returns epoch seconds; tests inject a fake clock
```

| Call | Behavior |
|---|---|
| `bs.create_event(event_id, name, capacity)` | `capacity` is an int ≥ 1. Duplicate `event_id` → `ValueError`. |
| `bs.available(event_id)` | capacity − confirmed seats − seats in active (unexpired) holds. Unknown event → `NotFound`. |
| `bs.hold(event_id, customer, seats, idem_key)` → `hold_id` (str) | Reserves seats for **600 seconds** of clock time. `seats` must be 1–6 (`ValueError`). Not enough available → `SoldOut`. Unknown event → `NotFound`. Retrying with the same `idem_key` returns the original `hold_id` and never reserves twice. |
| `bs.confirm(hold_id)` → `booking_id` (str) | Expired hold → `HoldExpired`; unknown → `NotFound`. Confirming the same hold again returns the same `booking_id`. |
| `bs.cancel(booking_id)` | Frees the seats. Cancelling twice is a no-op. Unknown → `NotFound`. |
| `bs.join_waitlist(event_id, customer, seats)` → position | 1-based position in that event's waitlist. |
| `bs.waitlist(event_id)` → list | Customer names in waitlist order. |
| `bs.holds_for(customer)` → list | That customer's active hold ids, oldest first. |

**Waitlist promotion.** Whenever seats free up (a cancel, or a hold found to be expired), the engine gives holds to waitlisted entries in strict FIFO order: the head of the waitlist gets a normal 600-second hold if its seats fit; the entry leaves the waitlist; repeat. Stop at the first entry that doesn't fit — never skip ahead. Expiry is evaluated against `clock()` on every call, so an expired hold is released (and promotion runs) the next time anything is called.

**Persistence.** A new `BookingSystem` on the same database file sees the same state.

**CLI.** `python3 -m booking report <db_path> <event_id>` prints one JSON object: `{"event_id", "capacity", "confirmed", "held", "available", "waitlist"}` where `confirmed`/`held` are seat counts and `waitlist` is the number of waiting entries.

Include automated tests.
