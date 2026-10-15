"""Continuity phase 3 — movements (built across an interrupted session)."""
import unittest
from invtest import Inv, TS


class Movements(Inv):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.srv.req("POST", "/items", {"sku": "M1", "name": "m", "price_cents": 1})
        cls.srv.req("POST", "/warehouses", {"code": "MA", "name": "a"})
        for q in (5, 5, 2, 9):          # the repeated 5 records nothing
            cls.srv.req("PUT", "/items/M1/stock/MA", {"qty": q})

    def test_log_and_pagination(self):
        mv = self.collect("/items/M1/movements")
        self.assertEqual([(m["delta"], m["qty_after"], m["warehouse"]) for m in mv], [(5, 5, "MA"), (-3, 2, "MA"), (7, 9, "MA")])
        self.assertTrue(all(TS.match(m["at"]) for m in mv))
        self.assertTrue(all(m["sku"] == "M1" for m in mv))

    def test_unknown_item(self):
        self.assertErr(self.req("GET", "/items/NOPE/movements"), 404, "not_found")


if __name__ == "__main__":
    unittest.main()
