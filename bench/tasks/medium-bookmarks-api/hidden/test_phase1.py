"""Hidden acceptance tests — medium-bookmarks-api."""
import unittest
from apptest import ServerTest, Server


class Create(ServerTest):
    ENTRY = "server.py"

    def test_create_ok(self):
        s, b, _ = self.req("POST", "/bookmarks", {"url": "https://a.example", "title": "A", "tags": ["x", "b", "x"]})
        self.assertEqual(s, 201)
        self.assertEqual(b["url"], "https://a.example")
        self.assertEqual(b["tags"], ["b", "x"])
        self.assertIn("id", b)
        self.assertIn("created_at", b)

    def test_bad_url(self):
        self.assertEqual(self.req("POST", "/bookmarks", {"url": "ftp://x", "title": "t"})[0], 400)
        self.assertEqual(self.req("POST", "/bookmarks", {"title": "t"})[0], 400)

    def test_empty_title(self):
        self.assertEqual(self.req("POST", "/bookmarks", {"url": "https://t.example", "title": ""})[0], 400)

    def test_duplicate(self):
        self.req("POST", "/bookmarks", {"url": "https://dup.example", "title": "d"})
        self.assertEqual(self.req("POST", "/bookmarks", {"url": "https://dup.example", "title": "d2"})[0], 409)

    def test_bad_json(self):
        self.assertEqual(self.req("POST", "/bookmarks", raw=b"{nope")[0], 400)

    def test_unknown_route(self):
        s, b, _ = self.req("GET", "/nope")
        self.assertEqual(s, 404)
        self.assertIsInstance(b, dict)


class ListAndFilter(ServerTest):
    ENTRY = "server.py"

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        for i in range(25):
            tags = ["even"] if i % 2 == 0 else ["odd"]
            if i % 5 == 0:
                tags.append("five")
            cls.srv.req("POST", "/bookmarks", {"url": "https://s%d.example" % i, "title": "Site %d %s" % (i, "Python" if i == 7 else ""), "tags": tags})

    def test_default_limit_and_total(self):
        s, b, _ = self.req("GET", "/bookmarks")
        self.assertEqual(s, 200)
        self.assertEqual(len(b["items"]), 20)
        self.assertEqual(b["total"], 25)
        ids = [i["id"] for i in b["items"]]
        self.assertEqual(ids, sorted(ids))

    def test_offset(self):
        b = self.req("GET", "/bookmarks?limit=10&offset=20")[1]
        self.assertEqual(len(b["items"]), 5)

    def test_limit_clamped(self):
        b = self.req("GET", "/bookmarks?limit=1000")[1]
        self.assertEqual(len(b["items"]), 25)

    def test_tag_filter(self):
        b = self.req("GET", "/bookmarks?tag=five")[1]
        self.assertEqual(b["total"], 5)

    def test_q_case_insensitive(self):
        b = self.req("GET", "/bookmarks?q=python")[1]
        self.assertEqual(b["total"], 1)

    def test_tags_counts_sorted(self):
        b = self.req("GET", "/tags")[1]
        self.assertEqual(b["tags"][:3], [{"name": "even", "count": 13}, {"name": "odd", "count": 12}, {"name": "five", "count": 5}])


class Mutate(ServerTest):
    ENTRY = "server.py"

    def test_get_patch_delete(self):
        bid = self.req("POST", "/bookmarks", {"url": "https://m.example", "title": "M"})[1]["id"]
        self.assertEqual(self.req("GET", "/bookmarks/%d" % bid)[0], 200)
        s, b, _ = self.req("PATCH", "/bookmarks/%d" % bid, {"title": "M2", "tags": ["z", "a"]})
        self.assertEqual(s, 200)
        self.assertEqual((b["title"], b["tags"]), ("M2", ["a", "z"]))
        self.assertEqual(self.req("PATCH", "/bookmarks/%d" % bid, {"url": "https://other.example"})[0], 400)
        s, body, _ = self.req("DELETE", "/bookmarks/%d" % bid)
        self.assertEqual(s, 204)
        self.assertEqual(self.req("GET", "/bookmarks/%d" % bid)[0], 404)
        self.assertEqual(self.req("DELETE", "/bookmarks/%d" % bid)[0], 404)
        self.assertEqual(self.req("PATCH", "/bookmarks/99999", {"title": "x"})[0], 404)


class SpecEdges(ServerTest):
    """Stated rules that a first draft commonly misses (added in bench v2)."""
    ENTRY = "server.py"

    def test_errors_are_json_for_unsupported_methods(self):
        s, b, _ = self.req("PUT", "/bookmarks/1", {"title": "x"})
        self.assertGreaterEqual(s, 400)
        self.assertIsInstance(b, dict)
        self.assertIn("error", b)

    def test_q_is_a_literal_substring(self):
        for t in ("foo_bar", "fooXbar", "100% done", "1000 done"):
            self.req("POST", "/bookmarks", {"url": "https://lit-%s.example" % t.replace(" ", "-").replace("%", "pct"), "title": t})
        self.assertEqual(self.req("GET", "/bookmarks?q=foo_bar")[1]["total"], 1)
        self.assertEqual(self.req("GET", "/bookmarks?q=100%25")[1]["total"], 1)


class Persistence(unittest.TestCase):
    def test_survives_restart(self):
        srv = Server("server.py").start()
        try:
            srv.req("POST", "/bookmarks", {"url": "https://keep.example", "title": "keep"})
        finally:
            srv.stop()
        again = Server("server.py", db_path=srv.db).start()
        try:
            self.assertEqual(again.req("GET", "/bookmarks?q=keep")[1]["total"], 1)
        finally:
            again.stop()


if __name__ == "__main__":
    unittest.main()
