"""SQLite access + forward-only migrations from migrations/NNN_*.sql."""
import os
import sqlite3

from app.log import get_logger

log = get_logger(__name__)
MIGRATIONS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "migrations")


def connect(path):
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY)")
    done = {r[0] for r in conn.execute("SELECT name FROM schema_migrations")}
    for name in sorted(f for f in os.listdir(MIGRATIONS) if f.endswith(".sql")):
        if name not in done:
            with open(os.path.join(MIGRATIONS, name)) as fh:
                conn.executescript(fh.read())
            conn.execute("INSERT INTO schema_migrations VALUES (?)", (name,))
            log.info("applied migration %s", name)
    conn.commit()
    return conn
