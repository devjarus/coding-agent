"""Session 1 — books, and the conventions stated once."""
import unittest
from libtest import Lib, TS


class Books(Lib):
    def test_feat_create_get_patch(self):
        b = self.book(title="Dune", author="Herbert", isbn="0441013597")
        self.assertEqual((b["title"], b["author"], b["isbn"]), ("Dune", "Herbert", "0441013597"))
        self.assertEqual(self.ok("GET", "/books/" + b["id"], status=200)["title"], "Dune")
        p = self.ok("PATCH", "/books/" + b["id"], {"title": "Dune Messiah"}, 200)
        self.assertEqual((p["title"], p["author"]), ("Dune Messiah", "Herbert"))
        self.assertIsNone(self.book()["isbn"])

    def test_conv_ids_and_timestamps(self):
        b = self.book()
        self.assertId(b["id"], "bk")
        self.assertRegex(b["created_at"], TS)

    def test_conv_error_shapes(self):
        self.assertErr(self.req("POST", "/books", {"title": "", "author": "a"}), 400, "validation_error")
        self.assertErr(self.req("POST", "/books", {"title": "t", "author": "a", "isbn": "12345"}), 400, "validation_error")
        self.assertErr(self.req("POST", "/books", raw=b"{nope"), 400, "validation_error")
        self.book(isbn="9780000000001")
        self.assertErr(self.req("POST", "/books", {"title": "t", "author": "a", "isbn": "9780000000001"}), 409, "conflict")
        self.assertErr(self.req("GET", "/books/bk_missing"), 404, "not_found")
        self.assertErr(self.req("GET", "/no/such/path"), 404, "not_found")
        b = self.book()
        self.assertErr(self.req("PATCH", "/books/" + b["id"], {"author": ""}), 400, "validation_error")


class BookPaging(Lib):
    def test_conv_cursor_pagination_oldest_first(self):
        ids = [self.book()["id"] for _ in range(5)]
        self.assertEqual([b["id"] for b in self.collect("/books")], ids)
        self.assertErr(self.req("GET", "/books?limit=0"), 400, "validation_error")


if __name__ == "__main__":
    unittest.main()
