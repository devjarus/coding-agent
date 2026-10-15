We're starting a library service in this empty repo. It will grow feature by feature over many sessions. Python 3 standard library only (`http.server`, `sqlite3`; no pip installs). Run contract: `python3 app.py --port PORT --db PATH`, serving on 127.0.0.1 and creating the schema if needed.

We've agreed on API conventions, and every endpoint we ever add must follow them:

- **Errors** are always `{"error": {"code": "<code>", "message": "<human text>"}}`. Codes: `validation_error` (400, including malformed JSON), `not_found` (404, including unknown paths), `conflict` (409).
- **IDs**: every resource we create gets a string `id` made of a short lowercase prefix for its type, an underscore, and letters/digits. Books use `bk_`; pick a short prefix for each new type.
- **Every list endpoint** uses cursor pagination: query params `limit` (default 20, max 100; anything outside 1..max is a `validation_error`) and `cursor`; the response is `{"items": [...], "next_cursor": <string or null>}`, with `next_cursor` `null` on the last page.
- **Timestamps** are ISO-8601 UTC strings ending in `Z`.
- **Money** is integer cents in fields whose names end in `_cents`.

First slice — books:

- `POST /books` `{"title", "author", "isbn"?}` → `201` `{"id", "title", "author", "isbn", "created_at"}` (`isbn` is `null` when absent). Title and author are required non-empty strings; an isbn, if given, is a string of exactly 10 or 13 digits. A duplicate isbn → `conflict`.
- `GET /books` → the paginated list, oldest first.
- `GET /books/{id}` → the book, or `not_found`.
- `PATCH /books/{id}` → update `title` and/or `author`, same validation.

Include automated tests.
