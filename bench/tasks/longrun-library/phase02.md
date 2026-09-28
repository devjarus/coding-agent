Next slice for the library service in this repo: members.

- `POST /members` `{"name", "email"}` → `201` `{"id", "name", "email", "created_at"}`. Name is required; email must have text on both sides of an `@`. Emails are unique ignoring case (`conflict`).
- `GET /members` → list, oldest first.
- `GET /members/{id}` → the member, or not found.

Follow the API conventions we agreed on.
