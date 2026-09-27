Build **Trackr**, a small issue tracker, in this empty repo. Python 3 standard library only (`http.server`, `sqlite3`, `hashlib`, …; no pip installs).

**Run contract:** `python3 app.py --port PORT --db PATH` serves on 127.0.0.1 and creates the schema if missing. JSON bodies everywhere; errors are `{"error": "<message>"}`.

### Users and auth
- `POST /api/users` `{"username", "password"}` → `201 {"id", "username"}`. Username: 3–20 chars of `a-z0-9_`; password at least 8 chars; otherwise `400`. Duplicate username → `409`. No auth needed.
- `POST /api/login` `{"username", "password"}` → `200 {"token"}`, or `401`.
- Every other `/api/*` endpoint requires `Authorization: Bearer <token>`; missing or invalid → `401`.
- Store passwords hashed with a per-user salt, never in plaintext.

### Projects
- `POST /api/projects` `{"key", "name"}` → `201 {"id", "key", "name", "owner"}`. `key` is 2–6 uppercase letters `A-Z`, unique (`409`), else `400`. The creator is the owner.
- `GET /api/projects` → `200 {"items": [...]}`: projects the caller owns or is a member of, ordered by key.
- `POST /api/projects/{key}/members` `{"username"}` → `201 {"key", "members": [...]}` (member usernames, sorted). Owner only (`403`); unknown user → `404`.
- Project-scoped endpoints: unknown project → `404`; a caller who is neither owner nor member → `403`.

### Issues
- `POST /api/projects/{key}/issues` `{"title", "description"?, "assignee"?}` → `201` issue:
  `{"ref": "KEY-N", "number": N, "title", "description", "status": "open", "assignee", "created_by", "created_at", "updated_at"}`.
  `number` is a per-project sequence starting at 1. `description` defaults to `""`, `assignee` to `null`. Empty title → `400`. The assignee must be the owner or a member (`400`).
- `GET /api/projects/{key}/issues` → `200 {"items", "total", "page", "per_page"}` ordered by number. Filters: `status`, `assignee`, `q` (case-insensitive substring of title or description). Paging: `page` (default 1), `per_page` (default 10, max 50 — larger values clamp to 50).
- `GET /api/issues/{ref}` → the issue plus `"comments": [...]` oldest first; unknown ref → `404`. Access rules follow the issue's project.
- `PATCH /api/issues/{ref}` — partial update of `title`, `description`, `assignee`, `status`. Allowed status moves:
  `open → in_progress | wont_fix`, `in_progress → open | done`, `done → open`, `wont_fix → open`.
  Other moves → `409`. Setting the current status again is a no-op. Unknown status value → `400`.
- `POST /api/issues/{ref}/comments` `{"body"}` → `201 {"id", "author", "body", "created_at"}`; empty body → `400`.

### UI
- `GET /` → an HTML page (`text/html`) with a login form (username and password fields). It only needs to be functional, not pretty; I don't need a design review.

Include automated tests.
