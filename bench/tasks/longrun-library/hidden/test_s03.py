"""Session 3 — loans (holds are only specified here; built in session 10)."""
import unittest
from libtest import Lib, TS, parse


class Loans(Lib):
    def test_feat_loan_and_due_date(self):
        b, m = self.book(), self.member()
        ln = self.loan(b["id"], m["id"])
        self.assertEqual((ln["book_id"], ln["member_id"], ln["returned_at"]), (b["id"], m["id"], None))
        self.assertEqual((parse(ln["due_at"]) - parse(ln["loaned_at"])).days, 14)
        self.assertIs(self.ok("GET", "/books/" + b["id"], status=200)["available"], False)

    def test_feat_return(self):
        b, m = self.book(), self.member()
        ln = self.loan(b["id"], m["id"])
        r = self.ok("POST", "/loans/%s/return" % ln["id"], None, 200)
        self.assertRegex(r["returned_at"], TS)
        self.assertIs(self.ok("GET", "/books/" + b["id"], status=200)["available"], True)
        self.assertErr(self.req("POST", "/loans/%s/return" % ln["id"]), 409, "conflict")

    def test_conv_ids_timestamps_errors(self):
        b, m = self.book(), self.member()
        ln = self.loan(b["id"], m["id"])
        self.assertId(ln["id"])
        self.assertRegex(ln["loaned_at"], TS)
        self.assertRegex(ln["due_at"], TS)
        self.assertErr(self.req("POST", "/loans", {"book_id": b["id"], "member_id": self.member()["id"]}), 409, "conflict")
        self.assertErr(self.req("POST", "/loans", {"book_id": "bk_missing", "member_id": m["id"]}), 404, "not_found")
        self.assertErr(self.req("POST", "/loans", {"book_id": b["id"], "member_id": "mb_missing"}), 404, "not_found")
        self.assertErr(self.req("POST", "/loans/ln_missing/return"), 404, "not_found")
        self.assertErr(self.req("GET", "/members/mb_missing/loans"), 404, "not_found")

    def test_conv_member_loans_paginated(self):
        m = self.member()
        ids = []
        for _ in range(3):
            ln = self.loan(self.book()["id"], m["id"])
            ids.append(ln["id"])
            self.ok("POST", "/loans/%s/return" % ln["id"], None, 200)
        self.assertEqual([x["id"] for x in self.collect("/members/%s/loans" % m["id"])], ids)


if __name__ == "__main__":
    unittest.main()
