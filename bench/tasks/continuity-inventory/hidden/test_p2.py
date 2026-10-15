"""Continuity phase 2 — warehouses + stock, under the phase-1 conventions."""
import unittest
from invtest import Inv, TS


class Warehouses(Inv):
    def test_create_list_conventions(self):
        for code in ("WB", "WA", "WC"):
            s, b, _ = self.req("POST", "/warehouses", {"code": code, "name": code})
            self.assertEqual(s, 201)
            self.assertRegex(b["created_at"], TS)
        self.assertEqual([w["code"] for w in self.collect("/warehouses")], ["WA", "WB", "WC"])
        self.assertErr(self.req("POST", "/warehouses", {"code": "WA", "name": "x"}), 409, "conflict")
        self.assertErr(self.req("POST", "/warehouses", {"code": "bad code", "name": "x"}), 400, "validation_error")


class Stock(Inv):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.srv.req("POST", "/items", {"sku": "S1", "name": "s", "price_cents": 1})
        for c in ("N1", "N2"):
            cls.srv.req("POST", "/warehouses", {"code": c, "name": c})

    def test_set_and_totals(self):
        s, b, _ = self.req("PUT", "/items/S1/stock/N1", {"qty": 5})
        self.assertEqual((s, b["qty"], b["warehouse"]), (200, 5, "N1"))
        self.req("PUT", "/items/S1/stock/N2", {"qty": 3})
        it = self.req("GET", "/items/S1")[1]
        self.assertEqual((it["stock"], it["total_qty"]), ({"N1": 5, "N2": 3}, 8))

    def test_stock_errors_follow_conventions(self):
        self.assertErr(self.req("PUT", "/items/NOPE/stock/N1", {"qty": 1}), 404, "not_found")
        self.assertErr(self.req("PUT", "/items/S1/stock/NOPE", {"qty": 1}), 404, "not_found")
        self.assertErr(self.req("PUT", "/items/S1/stock/N1", {"qty": -1}), 400, "validation_error")


if __name__ == "__main__":
    unittest.main()
