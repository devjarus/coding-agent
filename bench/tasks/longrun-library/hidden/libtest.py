"""Shared checks for the long-horizon library task.

Test names carry the behaviour they measure (score.py tallies them):
  conv    a convention stated once in session 1, applied to a later feature
  dec     the session-4 decision (default limit 50, max 200) that supersedes session 1's
  defer   work specified in one session and requested much later by reference only
  resume  the feature whose session was killed and resumed blind
  feat    the feature asked for in that session
"""
import datetime
import itertools
import re
from apptest import ServerTest

TS = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$")
ID = re.compile(r"^[a-z]{1,5}_[A-Za-z0-9]+$")
_n = itertools.count(1)


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def ago(days=0, seconds=0):
    return iso(datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days, seconds=seconds))


def parse(ts):
    return datetime.datetime.fromisoformat(ts[:-1].split(".")[0]).replace(tzinfo=datetime.timezone.utc)


def norm(obj):
    """Stringify id-like fields, so a broken ID convention fails only conv tests."""
    if isinstance(obj, dict):
        return {k: (str(v) if (k == "id" or k.endswith("_id") or k == "reserved_for") and v is not None
                    and not isinstance(v, str) else v) for k, v in obj.items()}
    return obj


class Lib(ServerTest):
    """Each behaviour is scored by its own tests: only conv tests check the error
    envelope and list envelope, so drifting from a convention costs conv points and
    does not also fail the feature built on top of it."""
    ENTRY = "app.py"

    def tag(self):
        parts = self._testMethodName.split("_")
        return parts[1] if len(parts) > 1 else ""

    def assertErr(self, resp, status, code):
        s, b, _ = resp
        self.assertEqual(s, status, b)
        if self.tag() != "conv":
            return
        self.assertIsInstance(b, dict, "error body must be JSON: %r" % (b,))
        self.assertIsInstance(b.get("error"), dict, "error must be an object: %r" % (b,))
        self.assertEqual(b["error"].get("code"), code)
        self.assertIsInstance(b["error"].get("message"), str)

    def assertId(self, v, prefix=None):
        self.assertRegex(v, ID)
        if prefix:
            self.assertTrue(v.startswith(prefix + "_"), v)

    def ok(self, method, path, body=None, status=None):
        s, b, _ = self.req(method, path, body)
        if status is not None:
            self.assertEqual(s, status, "%s %s -> %s %r" % (method, path, s, b))
        else:
            self.assertLess(s, 300, "%s %s -> %s %r" % (method, path, s, b))
        return norm(b)

    def book(self, **kw):
        body = {"title": "Title %d" % next(_n), "author": "Author"}
        body.update(kw)
        return self.ok("POST", "/books", body, 201)

    def member(self):
        n = next(_n)
        return self.ok("POST", "/members", {"name": "M%d" % n, "email": "m%d@x.test" % n}, 201)

    def loan(self, book_id, member_id, **kw):
        body = {"book_id": book_id, "member_id": member_id}
        body.update(kw)
        return self.ok("POST", "/loans", body, 201)

    def collect(self, path, limit=2):
        """Walk every page via next_cursor; return all items."""
        items, cursor, pages = [], None, 0
        while True:
            sep = "&" if "?" in path else "?"
            url = "%s%slimit=%d" % (path, sep, limit) + ("&cursor=%s" % cursor if cursor else "")
            s, b, _ = self.req("GET", url)
            self.assertEqual(s, 200, "%s -> %r" % (url, b))
            if self.tag() not in ("conv", "dec") and not (isinstance(b, dict) and "next_cursor" in b):
                # Not our list envelope: read the list in one large page instead.
                s, b, _ = self.req("GET", "%s%slimit=200" % (path, sep))
                rows = b if isinstance(b, list) else next((v for v in (b or {}).values() if isinstance(v, list)), [])
                return [norm(r) for r in rows]
            self.assertIsInstance(b, dict, "%s must return an object" % url)
            self.assertIn("next_cursor", b, "%s is not cursor-paginated: %r" % (url, list(b)))
            self.assertLessEqual(len(b["items"]), limit)
            items += [norm(r) for r in b["items"]]
            pages += 1
            cursor = b["next_cursor"]
            if cursor is None:
                return items
            self.assertLess(pages, 200, "pagination never ends")

    def assertPagePolicy(self, path, count):
        """Session 4: default limit 50, max 200. `count` rows (>= 55) must exist."""
        sep = "&" if "?" in path else "?"
        s, b, _ = self.req("GET", path)
        self.assertEqual(s, 200, b)
        self.assertEqual(len(b["items"]), 50, "default page size must be 50")
        self.assertIsNotNone(b["next_cursor"])
        s, b, _ = self.req("GET", path + sep + "limit=150")
        self.assertEqual(s, 200, "limit=150 must be accepted: %r" % (b,))
        self.assertEqual(len(b["items"]), min(150, count))
        self.assertErr(self.req("GET", path + sep + "limit=201"), 400, "validation_error")
