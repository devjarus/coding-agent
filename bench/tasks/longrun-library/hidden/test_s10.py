"""Session 10 — "build everything we said we'd do later": holds (specified in
session 3) and borrowing limits (specified in session 8)."""
import unittest
from libtest import Lib, TS


class Holds(Lib):
    def out(self):
        b, m = self.book(), self.member()
        return b, m, self.loan(b["id"], m["id"])

    def test_defer_place_hold(self):
        b, _, _ = self.out()
        h1, h2 = self.member(), self.member()
        h = self.ok("POST", "/holds", {"book_id": b["id"], "member_id": h1["id"]}, 201)
        self.assertEqual((h["book_id"], h["member_id"]), (b["id"], h1["id"]))
        self.ok("POST", "/holds", {"book_id": b["id"], "member_id": h2["id"]}, 201)
        self.assertEqual([x["member_id"] for x in self.collect("/books/%s/holds" % b["id"])], [h1["id"], h2["id"]])

    def test_conv_hold_ids_timestamps_errors(self):
        b, _, _ = self.out()
        h = self.ok("POST", "/holds", {"book_id": b["id"], "member_id": self.member()["id"]}, 201)
        self.assertId(h["id"])
        self.assertRegex(h["created_at"], TS)
        self.assertErr(self.req("POST", "/holds", {"book_id": "bk_missing", "member_id": self.member()["id"]}), 404, "not_found")

    def test_defer_hold_rules(self):
        free = self.book()
        m = self.member()
        self.assertErr(self.req("POST", "/holds", {"book_id": free["id"], "member_id": m["id"]}), 400, "validation_error")
        b, _, _ = self.out()
        self.ok("POST", "/holds", {"book_id": b["id"], "member_id": m["id"]}, 201)
        self.assertErr(self.req("POST", "/holds", {"book_id": b["id"], "member_id": m["id"]}), 409, "conflict")
        self.assertErr(self.req("POST", "/holds", {"book_id": "bk_missing", "member_id": m["id"]}), 404, "not_found")
        self.assertErr(self.req("GET", "/books/bk_missing/holds"), 404, "not_found")

    def test_defer_reservation_on_return(self):
        b, _, ln = self.out()
        h1, h2, other = self.member(), self.member(), self.member()
        self.ok("POST", "/holds", {"book_id": b["id"], "member_id": h1["id"]}, 201)
        self.ok("POST", "/holds", {"book_id": b["id"], "member_id": h2["id"]}, 201)
        self.assertIsNone(self.ok("GET", "/books/" + b["id"], status=200).get("reserved_for", "missing"))
        self.ok("POST", "/loans/%s/return" % ln["id"], None, 200)
        g = self.ok("GET", "/books/" + b["id"], status=200)
        self.assertEqual((g["available"], g["reserved_for"]), (False, h1["id"]))
        self.assertErr(self.req("POST", "/loans", {"book_id": b["id"], "member_id": other["id"]}), 409, "conflict")
        self.assertErr(self.req("POST", "/loans", {"book_id": b["id"], "member_id": h2["id"]}), 409, "conflict")
        ln2 = self.loan(b["id"], h1["id"])
        self.assertEqual([x["member_id"] for x in self.collect("/books/%s/holds" % b["id"])], [h2["id"]])
        self.ok("POST", "/loans/%s/return" % ln2["id"], None, 200)
        self.assertEqual(self.ok("GET", "/books/" + b["id"], status=200)["reserved_for"], h2["id"])

    def test_defer_no_holds_means_available(self):
        b, _, ln = self.out()
        self.ok("POST", "/loans/%s/return" % ln["id"], None, 200)
        g = self.ok("GET", "/books/" + b["id"], status=200)
        self.assertEqual((g["available"], g.get("reserved_for", "missing")), (True, None))


class HoldList(Lib):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        t = cls("run")
        cls.b = t.book()
        t.loan(cls.b["id"], t.member()["id"])
        for _ in range(55):
            t.ok("POST", "/holds", {"book_id": cls.b["id"], "member_id": t.member()["id"]}, 201)

    def test_dec_page_policy(self):
        self.assertPagePolicy("/books/%s/holds" % self.b["id"], 55)


class BorrowingLimits(Lib):
    def test_defer_three_open_loans(self):
        m = self.member()
        loans = [self.loan(self.book()["id"], m["id"]) for _ in range(3)]
        self.assertErr(self.req("POST", "/loans", {"book_id": self.book()["id"], "member_id": m["id"]}), 409, "conflict")
        self.ok("POST", "/loans/%s/return" % loans[0]["id"], None, 200)
        self.loan(self.book()["id"], m["id"])

    def test_defer_balance_blocks_borrowing(self):
        m = self.member()
        ln = self.loan(self.book()["id"], m["id"], loaned_at=self.days_ago(20))
        self.ok("POST", "/loans/%s/return" % ln["id"], None, 200)
        owed = self.ok("GET", "/members/" + m["id"], status=200)["balance_cents"]
        self.assertGreater(owed, 0)
        self.assertErr(self.req("POST", "/loans", {"book_id": self.book()["id"], "member_id": m["id"]}), 409, "conflict")
        self.ok("POST", "/members/%s/payments" % m["id"], {"amount_cents": owed}, 201)
        self.loan(self.book()["id"], m["id"])

    def days_ago(self, d):
        from libtest import ago
        return ago(days=d)


if __name__ == "__main__":
    unittest.main()
