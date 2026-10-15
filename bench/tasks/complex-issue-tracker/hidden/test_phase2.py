"""Hidden acceptance tests — Trackr phase 2 (labels, history, done rule)."""
import unittest
from apptest import ServerTest


class Base(ServerTest):
    ENTRY = "app.py"

    @classmethod
    def user(cls, name, pw="password123"):
        cls.srv.req("POST", "/api/users", {"username": name, "password": pw})
        return cls.srv.req("POST", "/api/login", {"username": name, "password": pw})[1]["token"]

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.own, cls.dev, cls.qa = cls.user("owner2"), cls.user("dev2"), cls.user("qa2")
        cls.srv.req("POST", "/api/projects", {"key": "LAB", "name": "Lab"}, token=cls.own)
        for u in ("dev2", "qa2"):
            cls.srv.req("POST", "/api/projects/LAB/members", {"username": u}, token=cls.own)

    def new(self, title="t", **kw):
        return self.req("POST", "/api/projects/LAB/issues", dict(title=title, **kw), token=self.own)[1]

    def patch(self, ref, body, tok=None):
        return self.req("PATCH", "/api/issues/" + ref, body, token=tok or self.own)


class Labels(Base):
    def test_create_list_validate(self):
        s, b, _ = self.req("POST", "/api/projects/LAB/labels", {"name": "bug", "color": "#FF0000"}, token=self.own)
        self.assertEqual((s, b["color"]), (201, "#ff0000"))
        self.req("POST", "/api/projects/LAB/labels", {"name": "api", "color": "#00ff00"}, token=self.own)
        self.assertEqual(self.req("POST", "/api/projects/LAB/labels", {"name": "bug", "color": "#000000"}, token=self.own)[0], 409)
        self.assertEqual(self.req("POST", "/api/projects/LAB/labels", {"name": "x", "color": "red"}, token=self.own)[0], 400)
        self.assertEqual(self.req("POST", "/api/projects/LAB/labels", {"name": "", "color": "#000000"}, token=self.own)[0], 400)
        names = [l["name"] for l in self.req("GET", "/api/projects/LAB/labels", token=self.dev)[1]["items"]]
        self.assertEqual(names[:2], ["api", "bug"])

    def test_issue_labels_and_filter(self):
        for n in ("ui", "zeta"):
            self.req("POST", "/api/projects/LAB/labels", {"name": n, "color": "#123abc"}, token=self.own)
        a = self.new("labelled")
        self.assertEqual(a["labels"], [])
        s, b, _ = self.patch(a["ref"], {"labels": ["zeta", "ui"]})
        self.assertEqual((s, b["labels"]), (200, ["ui", "zeta"]))
        self.assertEqual(self.patch(a["ref"], {"labels": ["nope"]})[0], 400)
        items = self.req("GET", "/api/projects/LAB/issues?label=zeta", token=self.own)[1]["items"]
        self.assertEqual([i["ref"] for i in items], [a["ref"]])
        self.assertEqual(self.req("GET", "/api/issues/" + a["ref"], token=self.own)[1]["labels"], ["ui", "zeta"])


class History(Base):
    def test_events_in_order(self):
        self.req("POST", "/api/projects/LAB/labels", {"name": "hist", "color": "#abcdef"}, token=self.own)
        ref = self.new("before")["ref"]
        self.patch(ref, {"title": "after"})
        self.patch(ref, {"assignee": "dev2"})
        self.patch(ref, {"status": "in_progress"}, self.dev)
        self.patch(ref, {"labels": ["hist"]})
        s, h, _ = self.req("GET", "/api/issues/%s/history" % ref, token=self.qa)
        self.assertEqual(s, 200)
        got = [(e["field"], e["from"], e["to"]) for e in h["items"]]
        self.assertEqual(got, [("title", "before", "after"), ("assignee", None, "dev2"),
                               ("status", "open", "in_progress"), ("labels", [], ["hist"])])
        self.assertEqual(h["items"][2]["actor"], "dev2")
        self.assertTrue(all("at" in e for e in h["items"]))

    def test_noop_patch_records_nothing(self):
        ref = self.new("same")["ref"]
        self.patch(ref, {"title": "same", "status": "open"})
        self.assertEqual(self.req("GET", "/api/issues/%s/history" % ref, token=self.own)[1]["items"], [])

    def test_description_not_tracked(self):
        ref = self.new("desc")["ref"]
        self.patch(ref, {"description": "changed"})
        self.assertEqual(self.req("GET", "/api/issues/%s/history" % ref, token=self.own)[1]["items"], [])


class DoneRule(Base):
    def test_requires_assignee(self):
        ref = self.new("unassigned")["ref"]
        self.patch(ref, {"status": "in_progress"})
        self.assertEqual(self.patch(ref, {"status": "done"})[0], 409)

    def test_only_assignee_or_owner(self):
        ref = self.new("guarded", assignee="dev2")["ref"]
        self.patch(ref, {"status": "in_progress"}, self.dev)
        self.assertEqual(self.patch(ref, {"status": "done"}, self.qa)[0], 403)
        self.assertEqual(self.patch(ref, {"status": "done"}, self.dev)[0], 200)
        ref2 = self.new("owner closes", assignee="dev2")["ref"]
        self.patch(ref2, {"status": "in_progress"})
        self.assertEqual(self.patch(ref2, {"status": "done"}, self.own)[0], 200)


if __name__ == "__main__":
    unittest.main()
