"""Continuity phase 5 — the deferred low-stock alerts, specified only in phase 2."""
import unittest
from invtest import Inv


class LowStock(Inv):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.srv.req("POST", "/warehouses", {"code": "LW", "name": "w"})
        for sku, qty, thr in (("L3", 1, 5), ("L1", 10, 5), ("L2", 0, 1), ("L4", 3, None), ("L5", 4, 4)):
            cls.srv.req("POST", "/items", {"sku": sku, "name": sku.lower(), "price_cents": 1})
            cls.srv.req("PUT", "/items/%s/stock/LW" % sku, {"qty": qty})
            if thr is not None:
                cls.srv.req("PATCH", "/items/" + sku, {"low_stock_threshold": thr})

    def test_alert_list(self):
        got = self.collect("/alerts/low-stock", limit=1)
        self.assertEqual([(a["sku"], a["total_qty"], a["low_stock_threshold"]) for a in got], [("L2", 0, 1), ("L3", 1, 5)])
        self.assertEqual(got[0]["name"], "l2")

    def test_threshold_validation(self):
        self.assertErr(self.req("PATCH", "/items/L1", {"low_stock_threshold": -1}), 400, "validation_error")


if __name__ == "__main__":
    unittest.main()
