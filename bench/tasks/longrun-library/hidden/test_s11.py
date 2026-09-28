"""Session 11 — overdue report."""
import datetime
import unittest
from libtest import Lib


class Overdue(Lib):
    def test_feat_report(self):
        now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
        mk = lambda days: self.loan(self.book()["id"], self.member()["id"], loaned_at=self.ts(now - datetime.timedelta(days=days)))
        a, b = mk(20), mk(30)  # due 6 and 16 days ago
        mk(5)  # not due yet
        c = mk(25)
        self.ok("POST", "/loans/%s/return" % c["id"], None, 200)  # returned: not overdue
        rows = [r for r in self.collect("/reports/overdue") if r["loan_id"] in (a["id"], b["id"], c["id"])]
        self.assertEqual([r["loan_id"] for r in rows], [b["id"], a["id"]])
        self.assertEqual([r["days_overdue"] for r in rows], [16, 6])
        self.assertEqual((rows[0]["book_id"], rows[0]["member_id"], rows[0]["due_at"]), (b["book_id"], b["member_id"], b["due_at"]))

    def test_feat_as_of(self):
        now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
        ln = self.loan(self.book()["id"], self.member()["id"], loaned_at=self.ts(now - datetime.timedelta(days=10)))
        due = now + datetime.timedelta(days=4)
        ids = lambda q: [r["loan_id"] for r in self.collect("/reports/overdue?as_of=" + q)]
        self.assertNotIn(ln["id"], ids(self.ts(due - datetime.timedelta(hours=1))))
        rows = [r for r in self.collect("/reports/overdue?as_of=" + self.ts(due + datetime.timedelta(days=2, hours=23))) if r["loan_id"] == ln["id"]]
        self.assertEqual([r["days_overdue"] for r in rows], [2])
        self.assertErr(self.req("GET", "/reports/overdue?as_of=tomorrow"), 400, "validation_error")


class OverduePaging(Lib):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        t = cls("run")
        members = [t.member()["id"] for _ in range(19)]
        for i in range(55):
            t.loan(t.book()["id"], members[i // 3], loaned_at=t.ago(days=30 + i))

    def test_dec_page_policy(self):
        self.assertPagePolicy("/reports/overdue", 55)


if __name__ == "__main__":
    unittest.main()
