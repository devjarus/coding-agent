"""Sessions 6-7 — reviews. Session 6 is killed mid-change; session 7 is told only to
pick up where it left off. Scored after session 7."""
import unittest
from libtest import Lib, TS


class Reviews(Lib):
    def borrowed(self, b):
        m = self.member()
        ln = self.loan(b["id"], m["id"])
        self.ok("POST", "/loans/%s/return" % ln["id"], None, 200)
        return m

    def test_resume_create_and_aggregate(self):
        b = self.book()
        g = self.ok("GET", "/books/" + b["id"], status=200)
        self.assertEqual((g["review_count"], g["avg_rating"]), (0, None))
        m1, m2, m3 = self.borrowed(b), self.borrowed(b), self.borrowed(b)
        r = self.ok("POST", "/books/%s/reviews" % b["id"], {"member_id": m1["id"], "rating": 5, "text": "great"}, 201)
        self.assertEqual((r["book_id"], r["member_id"], r["rating"], r["text"]), (b["id"], m1["id"], 5, "great"))
        r2 = self.ok("POST", "/books/%s/reviews" % b["id"], {"member_id": m2["id"], "rating": 4}, 201)
        self.assertIsNone(r2["text"])
        self.ok("POST", "/books/%s/reviews" % b["id"], {"member_id": m3["id"], "rating": 4}, 201)
        g = self.ok("GET", "/books/" + b["id"], status=200)
        self.assertEqual((g["review_count"], g["avg_rating"]), (3, 4.33))

    def test_resume_rules(self):
        b = self.book()
        m = self.borrowed(b)
        stranger = self.member()
        self.assertErr(self.req("POST", "/books/%s/reviews" % b["id"], {"member_id": stranger["id"], "rating": 3}), 400, "validation_error")
        for bad in (0, 6, 3.5, "4", True):
            self.assertErr(self.req("POST", "/books/%s/reviews" % b["id"], {"member_id": m["id"], "rating": bad}), 400, "validation_error")
        self.assertErr(self.req("POST", "/books/%s/reviews" % b["id"], {"member_id": m["id"], "rating": 3, "text": "x" * 501}), 400, "validation_error")
        self.ok("POST", "/books/%s/reviews" % b["id"], {"member_id": m["id"], "rating": 3, "text": "x" * 500}, 201)
        self.assertErr(self.req("POST", "/books/%s/reviews" % b["id"], {"member_id": m["id"], "rating": 2}), 409, "conflict")

    def test_resume_open_loan_counts_as_borrowed(self):
        b, m = self.book(), self.member()
        self.loan(b["id"], m["id"])
        self.ok("POST", "/books/%s/reviews" % b["id"], {"member_id": m["id"], "rating": 2}, 201)

    def test_conv_ids_timestamps_errors(self):
        b = self.book()
        m = self.borrowed(b)
        r = self.ok("POST", "/books/%s/reviews" % b["id"], {"member_id": m["id"], "rating": 1}, 201)
        self.assertId(r["id"])
        self.assertRegex(r["created_at"], TS)
        self.assertErr(self.req("POST", "/books/bk_missing/reviews", {"member_id": m["id"], "rating": 1}), 404, "not_found")
        self.assertErr(self.req("POST", "/books/%s/reviews" % b["id"], {"member_id": "mb_missing", "rating": 1}), 404, "not_found")
        self.assertErr(self.req("GET", "/books/bk_missing/reviews"), 404, "not_found")


class ReviewList(Lib):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        t = cls("run")
        cls.b = t.book()
        cls.ids = []
        for i in range(55):
            m = t.member()
            ln = t.loan(cls.b["id"], m["id"])
            t.ok("POST", "/loans/%s/return" % ln["id"], None, 200)
            cls.ids.append(t.ok("POST", "/books/%s/reviews" % cls.b["id"], {"member_id": m["id"], "rating": 1 + i % 5}, 201)["id"])

    def test_resume_newest_first_paginated(self):
        self.assertEqual([r["id"] for r in self.collect("/books/%s/reviews" % self.b["id"], limit=20)], self.ids[::-1])

    def test_conv_list_envelope(self):
        self.assertEqual(len(self.collect("/books/%s/reviews" % self.b["id"], limit=20)), 55)

    def test_dec_page_policy(self):
        self.assertPagePolicy("/books/%s/reviews" % self.b["id"], 55)


if __name__ == "__main__":
    unittest.main()
