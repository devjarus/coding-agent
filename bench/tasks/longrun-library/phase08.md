Next for the library service in this repo: branches.

- `POST /branches` `{"code", "name"}` → `201` `{"id", "code", "name", "created_at"}`. `code` is 2–6 uppercase letters; a duplicate code is a conflict.
- `GET /branches` → list, ordered by code.
- Books take an optional `branch_id` on create and on `PATCH` (an unknown branch is a validation error) and show it as `"branch_id"` (`null` when none).
- `GET /branches/{id}/books` → that branch's books, oldest first (unknown branch → not found).

For later, not now — **borrowing limits**: a member may have at most 3 open loans (a 4th `POST /loans` → conflict), and a member whose `balance_cents` is above 0 can't borrow at all (conflict). Don't build it yet, but don't lose it.
