"""Session 9 — search."""
import unittest
from libtest import Lib


class Search(Lib):
    def test_feat_title_or_author_ignoring_case(self):
        a = self.book(title="The Wizard of Earthsea", author="Ursula")["id"]
        b = self.book(title="Tales", author="Lord WIZARDRY")["id"]
        self.book(title="Unrelated", author="Nobody")
        self.assertEqual([x["id"] for x in self.collect("/books/search?q=wizard")], [a, b])

    def test_feat_literal_wildcards(self):
        pct = self.book(title="100% Cotton", author="Weaver")["id"]
        und = self.book(title="snake_case", author="Py")["id"]
        self.book(title="1000 Cottons", author="Weaver")
        self.book(title="snakeXcase", author="Py")
        self.assertEqual([x["id"] for x in self.collect("/books/search?q=0%25")], [pct])
        self.assertEqual([x["id"] for x in self.collect("/books/search?q=e_c")], [und])

    def test_conv_errors(self):
        self.assertErr(self.req("GET", "/books/search"), 400, "validation_error")
        self.assertErr(self.req("GET", "/books/search?q="), 400, "validation_error")


class SearchPaging(Lib):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        t = cls("run")
        for _ in range(55):
            t.book(title="Common Title")
        t.book(title="Other")

    def test_conv_list_envelope(self):
        self.assertEqual(len(self.collect("/books/search?q=common", limit=20)), 55)

    def test_dec_page_policy(self):
        self.assertPagePolicy("/books/search?q=common", 55)


if __name__ == "__main__":
    unittest.main()
