Trackr (in this repo) is in use and we need three changes. All existing behavior must keep working, and existing databases must keep working (migrate the schema if you need to).

1. **Labels.** `POST /api/projects/{key}/labels` `{"name", "color"}` → `201 {"name", "color"}`. `name` is 1–20 chars; `color` is `#rrggbb` hex (return it lowercase). Duplicate name in the project → `409`; invalid → `400`. `GET /api/projects/{key}/labels` → `{"items": [...]}` sorted by name. `PATCH /api/issues/{ref}` accepts `"labels": [names]`, replacing the issue's labels; an unknown label → `400`. Every issue JSON gains `"labels"`: a sorted list of names (default `[]`). The issue list accepts a `label` filter.

2. **History.** Every change made through `PATCH /api/issues/{ref}` to `status`, `assignee`, `title` or `labels` records an event. `GET /api/issues/{ref}/history` → `{"items": [{"at", "actor", "field", "from", "to"}]}` oldest first. For labels, `from`/`to` are sorted lists. A PATCH that sets a field to its current value records nothing for that field.

3. **Rule change for done.** Moving an issue to `done` requires an assignee (`409` if there is none), and only the assignee or the project owner may move it to `done` (`403` for anyone else).

Update the tests.
