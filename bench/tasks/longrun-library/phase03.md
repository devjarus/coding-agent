Next slice for the library service in this repo: loans.

- `POST /loans` `{"book_id", "member_id"}` → `201` `{"id", "book_id", "member_id", "loaned_at", "due_at", "returned_at"}`; `due_at` is 14 days after `loaned_at`, `returned_at` is `null`. Unknown book or member → not found. A book that is already out on an open loan → conflict.
- `POST /loans/{id}/return` → `200` with the loan, `returned_at` set. Returning a loan twice → conflict.
- `GET /members/{id}/loans` → that member's loans, oldest first (unknown member → not found).
- `GET /books/{id}` now also includes `"available"`: `true` unless the book is out on an open loan.

Same conventions as the rest of the service.

For later, not now — **holds**: a member can place a hold on a book that is currently out on loan: `POST /holds` `{"book_id", "member_id"}` → `201` `{"id", "book_id", "member_id", "created_at"}`. A hold on a book that isn't out on loan is a validation error; the same member holding the same book twice is a conflict. `GET /books/{id}/holds` lists its holds oldest first. When a book with holds comes back, it is reserved for the oldest hold: `GET /books/{id}` shows `"available": false` and `"reserved_for": "<member id>"` (`null` when not reserved), only that member may borrow it (anyone else → conflict), and when they do, their hold is removed. Don't build it yet, but make sure it doesn't get lost.
