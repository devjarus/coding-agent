"""Continuity phase 1 — items + conventions."""
import unittest
from invtest import Inv, TS


class Items(Inv):
    def test_create_shape(self):
        s, b, _ = self.req("POST", "/items", {"sku": "A1", "name": "Apple", "price_cents": 120})
        self.assertEqual(s, 201)
        self.assertEqual((b["sku"], b["name"], b["price_cents"]), ("A1", "Apple", 120))
        self.assertRegex(b["created_at"], TS)

    def test_validation_errors(self):
        self.assertErr(self.req("POST", "/items", {"sku": "", "name": "x", "price_cents": 1}), 400, "validation_error")
        self.assertErr(self.req("POST", "/items", {"sku": "V1", "name": "x", "price_cents": -5}), 400, "validation_error")
        self.assertErr(self.req("POST", "/items", {"sku": "V2", "name": "x", "price_cents": "1"}), 400, "validation_error")

    def test_conflict_and_not_found(self):
        self.req("POST", "/items", {"sku": "D1", "name": "d", "price_cents": 1})
        self.assertErr(self.req("POST", "/items", {"sku": "D1", "name": "d", "price_cents": 1}), 409, "conflict")
        self.assertErr(self.req("GET", "/items/NOPE"), 404, "not_found")

    def test_patch(self):
        self.req("POST", "/items", {"sku": "P1", "name": "p", "price_cents": 1})
        s, b, _ = self.req("PATCH", "/items/P1", {"name": "pp", "price_cents": 7})
        self.assertEqual((s, b["name"], b["price_cents"]), (200, "pp", 7))
        self.assertErr(self.req("PATCH", "/items/P1", {"price_cents": -1}), 400, "validation_error")


class ItemPaging(Inv):
    def test_cursor_pagination_ordered_by_sku(self):
        for sku in ("C3", "C1", "C5", "C2", "C4"):
            self.req("POST", "/items", {"sku": sku, "name": sku, "price_cents": 1})
        got = [i["sku"] for i in self.collect("/items")]
        self.assertEqual(got, ["C1", "C2", "C3", "C4", "C5"])


if __name__ == "__main__":
    unittest.main()
