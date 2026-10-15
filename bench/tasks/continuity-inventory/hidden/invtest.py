"""Shared checks for the continuity task: the phase-1 conventions."""
import re
from apptest import ServerTest

TS = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$")


class Inv(ServerTest):
    ENTRY = "app.py"

    def assertErr(self, resp, status, code):
        s, b, _ = resp
        self.assertEqual(s, status)
        self.assertIsInstance(b, dict)
        self.assertIsInstance(b.get("error"), dict, "error must be an object: %r" % (b,))
        self.assertEqual(b["error"].get("code"), code)
        self.assertIsInstance(b["error"].get("message"), str)

    def collect(self, path, limit=2):
        """Walk every page via next_cursor; return all items."""
        items, cursor, pages = [], None, 0
        while True:
            sep = "&" if "?" in path else "?"
            url = "%s%slimit=%d" % (path, sep, limit) + ("&cursor=%s" % cursor if cursor else "")
            s, b, _ = self.req("GET", url)
            self.assertEqual(s, 200, url)
            self.assertIn("next_cursor", b)
            self.assertLessEqual(len(b["items"]), limit)
            items += b["items"]
            pages += 1
            cursor = b["next_cursor"]
            if cursor is None:
                return items
            self.assertLess(pages, 100, "pagination never ends")
