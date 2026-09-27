"""Hidden acceptance tests — Trackr phase 1 (also run as the phase-2 regression suite).

Written to stay valid under the phase-2 rule change: anything moved to `done`
has an assignee and is moved by the assignee or the owner.
"""
import glob
import unittest
from apptest import ServerTest


class Base(ServerTest):
    ENTRY = "app.py"

    @classmethod
    def user(cls, name, pw="password123"):
        cls.srv.req("POST", "/api/users", {"username": name, "password": pw})
        return cls.srv.req("POST", "/api/login", {"username": name, "password": pw})[1]["token"]


class Auth(Base):
    def test_register_validation(self):
        self.assertEqual(self.req("POST", "/api/users", {"username": "ok_user1", "password": "longenough"})[0], 201)
        self.assertEqual(self.req("POST", "/api/users", {"username": "ok_user1", "password": "longenough"})[0], 409)
        self.assertEqual(self.req("POST", "/api/users", {"username": "ab", "password": "longenough"})[0], 400)
        self.assertEqual(self.req("POST", "/api/users", {"username": "Bad-Name", "password": "longenough"})[0], 400)
        self.assertEqual(self.req("POST", "/api/users", {"username": "shortpw", "password": "short"})[0], 400)

    def test_login(self):
        self.req("POST", "/api/users", {"username": "logan", "password": "secret-pass"})
        s, b, _ = self.req("POST", "/api/login", {"username": "logan", "password": "secret-pass"})
        self.assertEqual(s, 200)
        self.assertTrue(b["token"])
        self.assertEqual(self.req("POST", "/api/login", {"username": "logan", "password": "wrong-pass"})[0], 401)

    def test_auth_required(self):
        self.assertEqual(self.req("GET", "/api/projects")[0], 401)
        self.assertEqual(self.req("GET", "/api/projects", token="garbage")[0], 401)

    def test_password_not_plaintext(self):
        self.req("POST", "/api/users", {"username": "plain", "password": "correct-horse-9"})
        blob = b""
        for f in glob.glob(self.srv.db + "*"):
            with open(f, "rb") as fh:
                blob += fh.read()
        self.assertNotIn(b"correct-horse-9", blob)


class Projects(Base):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.alice, cls.bob, cls.carol = cls.user("alice"), cls.user("bob"), cls.user("carol")

    def test_create_and_validate(self):
        s, b, _ = self.req("POST", "/api/projects", {"key": "WEB", "name": "Website"}, token=self.alice)
        self.assertEqual(s, 201)
        self.assertEqual((b["key"], b["owner"]), ("WEB", "alice"))
        self.assertEqual(self.req("POST", "/api/projects", {"key": "WEB", "name": "x"}, token=self.bob)[0], 409)
        for bad in ("w", "web", "TOOLONGKEY", "W3B"):
            self.assertEqual(self.req("POST", "/api/projects", {"key": bad, "name": "x"}, token=self.alice)[0], 400, bad)

    def test_membership_and_access(self):
        self.req("POST", "/api/projects", {"key": "OPS", "name": "Ops"}, token=self.alice)
        self.assertEqual(self.req("GET", "/api/projects/OPS/issues", token=self.bob)[0], 403)
        self.assertEqual(self.req("POST", "/api/projects/OPS/members", {"username": "carol"}, token=self.bob)[0], 403)
        self.assertEqual(self.req("POST", "/api/projects/OPS/members", {"username": "nobody"}, token=self.alice)[0], 404)
        s, b, _ = self.req("POST", "/api/projects/OPS/members", {"username": "bob"}, token=self.alice)
        self.assertEqual(s, 201)
        # The spec doesn't say whether the owner is listed as a member: accept both.
        self.assertIn(b["members"], (["bob"], ["alice", "bob"]))
        self.assertEqual(self.req("GET", "/api/projects/OPS/issues", token=self.bob)[0], 200)
        keys = [p["key"] for p in self.req("GET", "/api/projects", token=self.bob)[1]["items"]]
        self.assertIn("OPS", keys)
        keys_c = [p["key"] for p in self.req("GET", "/api/projects", token=self.carol)[1]["items"]]
        self.assertNotIn("OPS", keys_c)
        self.assertEqual(self.req("GET", "/api/projects/NOPE/issues", token=self.alice)[0], 404)

    def test_list_sorted(self):
        t = self.user("sorter")
        for k in ("ZED", "ABC", "MID"):
            self.req("POST", "/api/projects", {"key": k, "name": k}, token=t)
        keys = [p["key"] for p in self.req("GET", "/api/projects", token=t)[1]["items"]]
        self.assertEqual(keys, ["ABC", "MID", "ZED"])


class Issues(Base):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.own, cls.mem, cls.out = cls.user("owner1"), cls.user("member1"), cls.user("outsider")
        cls.srv.req("POST", "/api/projects", {"key": "APP", "name": "App"}, token=cls.own)
        cls.srv.req("POST", "/api/projects/APP/members", {"username": "member1"}, token=cls.own)

    def new(self, title, **kw):
        body = dict(title=title, **kw)
        return self.req("POST", "/api/projects/APP/issues", body, token=self.own)

    def test_create_shape_and_sequence(self):
        s, a, _ = self.new("First issue", description="details")
        self.assertEqual(s, 201)
        s2, b, _ = self.new("Second")
        self.assertEqual(b["number"], a["number"] + 1)
        self.assertEqual(a["ref"], "APP-%d" % a["number"])
        self.assertEqual((a["status"], a["assignee"], a["created_by"], a["description"]), ("open", None, "owner1", "details"))
        self.assertEqual(b["description"], "")
        for k in ("created_at", "updated_at", "title"):
            self.assertIn(k, a)

    def test_create_validation(self):
        self.assertEqual(self.new("")[0], 400)
        self.assertEqual(self.new("x", assignee="outsider")[0], 400)
        self.assertEqual(self.new("x", assignee="member1")[0], 201)
        self.assertEqual(self.req("POST", "/api/projects/APP/issues", {"title": "x"}, token=self.out)[0], 403)

    def test_transitions(self):
        ref = self.new("Flow", assignee="member1")[1]["ref"]
        p = lambda st, tok=None: self.req("PATCH", "/api/issues/" + ref, {"status": st}, token=tok or self.own)[0]
        self.assertEqual(p("done"), 409)          # open -> done not allowed
        self.assertEqual(p("in_progress"), 200)
        self.assertEqual(p("in_progress"), 200)   # same status is a no-op
        self.assertEqual(p("wont_fix"), 409)      # in_progress -> wont_fix not allowed
        self.assertEqual(p("done", self.mem), 200)  # assignee completes
        self.assertEqual(p("open"), 200)          # reopen
        self.assertEqual(p("wont_fix"), 200)
        self.assertEqual(p("in_progress"), 409)   # wont_fix -> in_progress not allowed
        self.assertEqual(p("open"), 200)
        self.assertEqual(p("bogus"), 400)
        self.assertEqual(self.req("GET", "/api/issues/" + ref, token=self.own)[1]["status"], "open")

    def test_patch_fields_and_updated_at(self):
        a = self.new("Old title")[1]
        s, b, _ = self.req("PATCH", "/api/issues/" + a["ref"], {"title": "New title", "assignee": "member1"}, token=self.mem)
        self.assertEqual(s, 200)
        self.assertEqual((b["title"], b["assignee"]), ("New title", "member1"))
        self.assertEqual(self.req("PATCH", "/api/issues/" + a["ref"], {"assignee": "outsider"}, token=self.own)[0], 400)
        self.assertEqual(self.req("PATCH", "/api/issues/" + a["ref"], {"title": "x"}, token=self.out)[0], 403)

    def test_comments_and_get(self):
        ref = self.new("Discuss")[1]["ref"]
        s, c, _ = self.req("POST", "/api/issues/%s/comments" % ref, {"body": "one"}, token=self.mem)
        self.assertEqual((s, c["author"], c["body"]), (201, "member1", "one"))
        self.req("POST", "/api/issues/%s/comments" % ref, {"body": "two"}, token=self.own)
        self.assertEqual(self.req("POST", "/api/issues/%s/comments" % ref, {"body": ""}, token=self.own)[0], 400)
        s, full, _ = self.req("GET", "/api/issues/" + ref, token=self.own)
        self.assertEqual([x["body"] for x in full["comments"]], ["one", "two"])
        self.assertEqual(self.req("GET", "/api/issues/APP-9999", token=self.own)[0], 404)
        self.assertEqual(self.req("GET", "/api/issues/" + ref, token=self.out)[0], 403)


class Search(Base):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.t = cls.user("searcher")
        cls.user("helper")
        cls.srv.req("POST", "/api/projects", {"key": "SRCH", "name": "Search"}, token=cls.t)
        cls.srv.req("POST", "/api/projects/SRCH/members", {"username": "helper"}, token=cls.t)
        for i in range(1, 61):
            body = {"title": "Issue %d" % i, "description": "needle here" if i % 10 == 0 else "hay"}
            if i % 3 == 0:
                body["assignee"] = "helper"
            ref = cls.srv.req("POST", "/api/projects/SRCH/issues", body, token=cls.t)[1]["ref"]
            if i % 4 == 0:
                cls.srv.req("PATCH", "/api/issues/" + ref, {"status": "in_progress"}, token=cls.t)

    def get(self, qs):
        return self.req("GET", "/api/projects/SRCH/issues" + qs, token=self.t)[1]

    def test_default_paging(self):
        b = self.get("")
        self.assertEqual((b["total"], b["page"], b["per_page"], len(b["items"])), (60, 1, 10, 10))
        self.assertEqual([i["number"] for i in b["items"]], list(range(1, 11)))

    def test_page_two_and_clamp(self):
        b = self.get("?page=2&per_page=25")
        self.assertEqual([i["number"] for i in b["items"]][:2], [26, 27])
        c = self.get("?per_page=500")
        self.assertEqual((c["per_page"], len(c["items"])), (50, 50))

    def test_filters(self):
        self.assertEqual(self.get("?status=in_progress")["total"], 15)
        self.assertEqual(self.get("?assignee=helper")["total"], 20)
        self.assertEqual(self.get("?q=NEEDLE")["total"], 6)
        self.assertEqual(self.get("?q=issue%205")["total"], 11)  # Issue 5 and Issue 50..59
        self.assertEqual(self.get("?status=in_progress&assignee=helper")["total"], 5)


class Ui(Base):
    def test_login_page(self):
        s, body, h = self.req("GET", "/")
        self.assertEqual(s, 200)
        self.assertIn("text/html", h.get("Content-Type", ""))
        low = body.lower()
        self.assertIn("<form", low)
        self.assertIn("password", low)


if __name__ == "__main__":
    unittest.main()
