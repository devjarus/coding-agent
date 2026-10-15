Late returns now cost money in the library service in this repo.

- `POST /loans` accepts an optional `loaned_at`, and `POST /loans/{id}/return` an optional `returned_at` (both timestamps in our usual format), so staff can enter paper records. Neither may be in the future, and `returned_at` can't be before `loaned_at` → validation error. `due_at` is still 14 days after `loaned_at`.
- A loan returned after its `due_at` gets a fine of 25 cents per started day late (one second late is one day). Every loan shows `fine_cents` (0 unless returned late).
- `GET /members/{id}` includes `balance_cents`: the member's fines minus their payments.
- `POST /members/{id}/payments` `{"amount_cents"}` → `201` `{"id", "member_id", "amount_cents", "created_at"}`. The amount must be a positive integer no larger than the current balance (validation error otherwise).
- `GET /members/{id}/payments` → that member's payments, oldest first.
