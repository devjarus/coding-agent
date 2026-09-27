We're starting an inventory service in this empty repo. Python 3 standard library only (`http.server`, `sqlite3`; no pip installs). Run contract: `python3 app.py --port PORT --db PATH`, serving on 127.0.0.1 and creating the schema if needed.

We've agreed on API conventions for this service, and every endpoint we ever add must follow them:

- **Errors** are always `{"error": {"code": "<code>", "message": "<human text>"}}`. Codes: `validation_error` (400), `not_found` (404), `conflict` (409).
- **Every list endpoint** uses cursor pagination: query params `limit` (default 20, max 100) and `cursor`; the response is `{"items": [...], "next_cursor": <string or null>}`. `next_cursor` is `null` on the last page.
- **Timestamps** are ISO-8601 UTC strings ending in `Z`.
- **Money** is integer cents in fields whose names end in `_cents`.

First slice — items:

- `POST /items` `{"sku", "name", "price_cents"}` → `201` with the item `{"sku", "name", "price_cents", "created_at"}`. Missing/empty sku or name, or a price that isn't a non-negative integer → `validation_error`. Duplicate sku → `conflict`.
- `GET /items` → the paginated list, ordered by sku.
- `GET /items/{sku}` → the item, or `not_found`.
- `PATCH /items/{sku}` → update `name` and/or `price_cents`; same validation.

Include automated tests.
