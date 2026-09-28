"""Session 5 — fines and payments."""
import unittest
import datetime
from libtest import Lib, TS, ago, iso, parse


class Fines(Lib):
    def late(self, days_late, seconds=0):
        """Loan 40 days ago (due 26 days ago), returned days_late days + seconds after due."""
        base = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0) - datetime.timedelta(days=40)
        due = base + datetime.timedelta(days=14)
        b, m = self.book(), self.member()
        ln = self.loan(b["id"], m["id"], loaned_at=iso(base))
        ret = self.ok("POST", "/loans/%s/return" % ln["id"],
                      {"returned_at": iso(due + datetime.timedelta(days=days_late, seconds=seconds))}, 200)
        return m, ret

    def test_feat_fines(self):
        self.assertEqual(self.late(3)[1]["fine_cents"], 75)
        self.assertEqual(self.late(0, seconds=1)[1]["fine_cents"], 25)
        self.assertEqual(self.late(-2)[1]["fine_cents"], 0)
        b, m = self.book(), self.member()
        self.assertEqual(self.loan(b["id"], m["id"])["fine_cents"], 0)

    def test_feat_backdating_rules(self):
        b, m = self.book(), self.member()
        ln = self.loan(b["id"], m["id"], loaned_at=ago(days=20))
        want = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=20)
        self.assertLess(abs((parse(ln["loaned_at"]) - want).total_seconds()), 120)
        self.assertLess(abs((parse(ln["due_at"]) - want - datetime.timedelta(days=14)).total_seconds()), 120)
        self.assertErr(self.req("POST", "/loans/%s/return" % ln["id"], {"returned_at": ago(days=21)}), 400, "validation_error")
        self.assertErr(self.req("POST", "/loans/%s/return" % ln["id"], {"returned_at": ago(days=-1)}), 400, "validation_error")
        self.assertErr(self.req("POST", "/loans", {"book_id": self.book()["id"], "member_id": m["id"], "loaned_at": ago(days=-1)}), 400, "validation_error")
        self.assertErr(self.req("POST", "/loans", {"book_id": self.book()["id"], "member_id": m["id"], "loaned_at": "yesterday"}), 400, "validation_error")

    def test_feat_balance_and_payments(self):
        m, _ = self.late(4)
        self.assertEqual(self.ok("GET", "/members/" + m["id"], status=200)["balance_cents"], 100)
        p = self.ok("POST", "/members/%s/payments" % m["id"], {"amount_cents": 60}, 201)
        self.assertEqual((p["member_id"], p["amount_cents"]), (m["id"], 60))
        self.assertEqual(self.ok("GET", "/members/" + m["id"], status=200)["balance_cents"], 40)
        self.assertErr(self.req("POST", "/members/%s/payments" % m["id"], {"amount_cents": 41}), 400, "validation_error")
        self.assertErr(self.req("POST", "/members/%s/payments" % m["id"], {"amount_cents": 0}), 400, "validation_error")
        self.assertErr(self.req("POST", "/members/%s/payments" % m["id"], {"amount_cents": "10"}), 400, "validation_error")

    def test_conv_payment_ids_timestamps_errors(self):
        m, _ = self.late(1)
        p = self.ok("POST", "/members/%s/payments" % m["id"], {"amount_cents": 5}, 201)
        self.assertId(p["id"])
        self.assertRegex(p["created_at"], TS)
        self.assertErr(self.req("POST", "/members/mb_missing/payments", {"amount_cents": 5}), 404, "not_found")
        self.assertErr(self.req("GET", "/members/mb_missing/payments"), 404, "not_found")


class PaymentList(Lib):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        t = cls("run")
        b = t.book()
        cls.m = t.member()
        ln = t.loan(b["id"], cls.m["id"], loaned_at=ago(days=200))
        t.ok("POST", "/loans/%s/return" % ln["id"], {"returned_at": ago(days=1)}, 200)
        cls.ids = [t.ok("POST", "/members/%s/payments" % cls.m["id"], {"amount_cents": 1}, 201)["id"] for _ in range(55)]

    def test_conv_payments_paginated_oldest_first(self):
        self.assertEqual([p["id"] for p in self.collect("/members/%s/payments" % self.m["id"], limit=20)], self.ids)

    def test_dec_payments_page_policy(self):
        self.assertPagePolicy("/members/%s/payments" % self.m["id"], 55)


if __name__ == "__main__":
    unittest.main()
