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


if __name__ == "__main__":
    unittest.main()
