import unittest

from tests.helpers import Server


class OrdersTest(unittest.TestCase):
    def test_create_and_pay(self):
        with Server() as s:
            st, o = s.call("POST", "/orders", {"customer": "ann", "items": [{"sku": "a", "qty": 2, "price_cents": 150}]})
            self.assertEqual((st, o["status"], o["total_cents"]), (201, "pending", 300))
            st, o = s.call("POST", "/orders/%d/pay" % o["id"])
            self.assertEqual((st, o["status"]), (200, "paid"))
            st, e = s.call("POST", "/orders/%d/pay" % o["id"])
            self.assertEqual((st, e["code"]), (409, "order_not_payable"))


class CancelTest(unittest.TestCase):
    def test_cancel_pending_only(self):
        with Server() as s:
            _, o = s.call("POST", "/orders", {"customer": "bo", "items": [{"sku": "a", "qty": 1, "price_cents": 5}]})
            st, c = s.call("POST", "/orders/%d/cancel" % o["id"], {"reason": "changed mind"})
            self.assertEqual((st, c["status"], c["cancel_reason"]), (200, "cancelled", "changed mind"))
            st, e = s.call("POST", "/orders/%d/cancel" % o["id"], {"reason": "again"})
            self.assertEqual((st, e["code"]), (409, "order_not_cancellable"))


if __name__ == "__main__":
    unittest.main()
