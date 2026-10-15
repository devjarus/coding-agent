"""Session 4 — the page-size decision (applies retroactively) + author filter."""
import unittest
from libtest import Lib


class PagePolicyExisting(Lib):
    """The decision must reach the endpoints built before it."""
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        t = cls("run")
        for _ in range(55):
            t.book()
            t.member()
        cls.m = t.member()
        b = t.book()
        for _ in range(55):
            ln = t.loan(b["id"], cls.m["id"])
            t.ok("POST", "/loans/%s/return" % ln["id"], None, 200)

    def test_dec_books(self):
        self.assertPagePolicy("/books", 56)

    def test_dec_members(self):
        self.assertPagePolicy("/members", 56)

    def test_dec_member_loans(self):
        self.assertPagePolicy("/members/%s/loans" % self.m["id"], 55)


class AuthorFilter(Lib):
    def test_feat_author_filter(self):
        a = [self.book(author="Le Guin")["id"], self.book(author="le guin")["id"]]
        self.book(author="Le Guinn")
        self.book(author="Tolkien")
        self.assertEqual([b["id"] for b in self.collect("/books?author=LE%20GUIN")], a)


if __name__ == "__main__":
    unittest.main()
