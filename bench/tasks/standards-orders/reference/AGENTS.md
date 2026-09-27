# Orders service — engineering standards

These rules apply to every change in this repository.

1. **Logging.** Use `from app.log import get_logger` and `log = get_logger(__name__)`.
   Every state change logs one `log.info(...)` line. Never use `print()` in `app/`.
2. **Errors.** Raise `ApiError(status, code, message)` from `app/errors.py` for
   every error response. Codes are `snake_case` and every code is listed in
   `docs/API.md`.
3. **Schema changes.** Add a new file `migrations/NNN_short_name.sql` using the
   next number. Never edit an existing migration — they have already run in
   production.
4. **Tests.** `unittest`, in `tests/test_<area>.py`. Every new or changed
   endpoint gets tests. Run: `python3 -m unittest discover -s tests -t .`
5. **Docs.** Update `docs/API.md` for every endpoint change.
6. **Changelog.** Add a line under `## Unreleased` in `CHANGELOG.md`.
7. **Money** is integer cents in fields ending in `_cents`.
