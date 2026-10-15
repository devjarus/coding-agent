Build a small bookmarks service in this empty repo. Python 3 standard library only (use `http.server` and `sqlite3`; no pip installs).

**Run contract:** `python3 server.py --port PORT --db PATH` starts the server on 127.0.0.1 and creates the database schema if it doesn't exist. Data must survive a restart with the same `--db`.

All request and response bodies are JSON. Errors return `{"error": "<message>"}`.

| Method & path | Behavior |
|---|---|
| `POST /bookmarks` | Body `{"url", "title", "tags": [..]}` (`tags` optional, default `[]`). → `201` with the bookmark `{"id", "url", "title", "tags", "created_at"}`. `400` if `url` is missing or not `http://`/`https://`, or `title` is empty/missing. `409` if the url already exists. |
| `GET /bookmarks` | → `200` `{"items": [...], "total": N}` ordered by `id` ascending. Query params: `tag` (exact tag match), `q` (case-insensitive substring of title), `limit` (default 20, max 100; larger values are clamped to 100), `offset` (default 0). `total` counts all matches, ignoring limit/offset. |
| `GET /bookmarks/{id}` | → `200` bookmark, or `404`. |
| `PATCH /bookmarks/{id}` | Partial update of `title` and/or `tags`. `url` cannot be changed: providing it → `400`. → `200` updated bookmark, or `404`. |
| `DELETE /bookmarks/{id}` | → `204` with no body, or `404`. |
| `GET /tags` | → `200` `{"tags": [{"name", "count"}]}` sorted by count descending, then name ascending. |

Also: an unknown route → `404` JSON; a request body that isn't valid JSON → `400`. Tags are stored and returned de-duplicated and sorted alphabetically.

Include automated tests for the service.
