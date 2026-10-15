import unittest
from decimal import Decimal

from pricing import line_total, order_total


class PricingTest(unittest.TestCase):
    def test_simple_line(self):
        self.assertEqual(line_total("2.50", 4), Decimal("10.00"))

    def test_order_with_tax(self):
        self.assertEqual(order_total([("10.00", 1)]), Decimal("10.80"))


if __name__ == "__main__":
    unittest.main()
