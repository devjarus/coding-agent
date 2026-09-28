"""Session 8 — branches (the borrowing limits are only specified here)."""
import unittest
from libtest import Lib, TS


class Branches(Lib):
    def test_feat_create_and_book_assignment(self):
        br = self.ok("POST", "/branches", {"code": "MAIN", "name": "Main"}, 201)
        self.assertEqual((br["code"], br["name"]), ("MAIN", "Main"))
        b1 = self.book(branch_id=br["id"])
        self.assertEqual(b1["branch_id"], br["id"])
        b2 = self.book()
        self.assertIsNone(b2["branch_id"])
        self.assertEqual(self.ok("PATCH", "/books/" + b2["id"], {"branch_id": br["id"]}, 200)["branch_id"], br["id"])
        self.book()
        self.assertEqual([b["id"] for b in self.collect("/branches/%s/books" % br["id"])], [b1["id"], b2["id"]])

    def test_feat_validation(self):
        self.ok("POST", "/branches", {"code": "EAST", "name": "East"}, 201)
        self.assertErr(self.req("POST", "/branches", {"code": "EAST", "name": "x"}), 409, "conflict")
        for bad in ("E", "TOOLONGX", "ea", "E1"):
            self.assertErr(self.req("POST", "/branches", {"code": bad, "name": "x"}), 400, "validation_error")
        self.assertErr(self.req("POST", "/books", {"title": "t", "author": "a", "branch_id": "br_missing"}), 400, "validation_error")
        b = self.book()
        self.assertErr(self.req("PATCH", "/books/" + b["id"], {"branch_id": "br_missing"}), 400, "validation_error")

    def test_conv_ids_timestamps_errors(self):
        br = self.ok("POST", "/branches", {"code": "WEST", "name": "West"}, 201)
        self.assertId(br["id"])
        self.assertRegex(br["created_at"], TS)
        self.assertErr(self.req("GET", "/branches/br_missing/books"), 404, "not_found")


class BranchLists(Lib):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        t = cls("run")
        codes = ["B" + "".join(chr(65 + (i // 26 ** k) % 26) for k in (1, 0)) for i in range(55)]
        cls.codes = sorted(codes)
        made = {c: t.ok("POST", "/branches", {"code": c, "name": c}, 201) for c in reversed(codes)}
        cls.br = made[cls.codes[0]]
        cls.books = [t.book(branch_id=cls.br["id"])["id"] for _ in range(55)]

    def test_feat_branches_ordered_by_code(self):
        self.assertEqual([b["code"] for b in self.collect("/branches", limit=20)], self.codes)

    def test_conv_list_envelopes(self):
        self.assertEqual(len(self.collect("/branches", limit=20)), 55)
        self.assertEqual(self.collect("/branches/%s/books" % self.br["id"], limit=20)[-1]["id"], self.books[-1])

    def test_dec_branches_page_policy(self):
        self.assertPagePolicy("/branches", 55)

    def test_dec_branch_books_page_policy(self):
        self.assertPagePolicy("/branches/%s/books" % self.br["id"], 55)


if __name__ == "__main__":
    unittest.main()
