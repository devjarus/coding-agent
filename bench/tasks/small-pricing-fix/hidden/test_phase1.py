"""Hidden acceptance tests — small-pricing-fix. Imports pricing from APP_DIR."""
import os, sys, unittest
from decimal import Decimal

sys.path.insert(0, os.environ["APP_DIR"])
from pricing import line_total, order_total  # noqa: E402


class Bulk(unittest.TestCase):
    def test_exactly_ten_gets_discount(self):
        self.assertEqual(line_total("1.00", 10), Decimal("9.00"))

    def test_nine_no_discount(self):
        self.assertEqual(line_total("1.00", 9), Decimal("9.00"))

    def test_eleven_discount(self):
        self.assertEqual(line_total("2.00", 11), Decimal("19.80"))


class Save5(unittest.TestCase):
    def test_floor_at_zero(self):
        self.assertEqual(order_total([("3.00", 1)], "SAVE5"), Decimal("0.00"))

    def test_normal(self):
        self.assertEqual(order_total([("20.00", 1)], "SAVE5"), Decimal("16.20"))

    def test_returns_decimal(self):
        self.assertIsInstance(order_total([("3.00", 1)], "SAVE5"), Decimal)


class Rounding(unittest.TestCase):
    def test_half_up(self):
        # subtotal 9.375 * 1.08 = 10.125 -> 10.13 (half up), 10.12 under banker's rounding
        self.assertEqual(order_total([("9.375", 1)]), Decimal("10.13"))

    def test_plain(self):
        self.assertEqual(order_total([("10.00", 1)]), Decimal("10.80"))


class Pct10(unittest.TestCase):
    def test_pct10(self):
        self.assertEqual(order_total([("100.00", 1)], "PCT10"), Decimal("97.20"))

    def test_pct10_after_bulk(self):
        # 10 x 10.00 -> 90.00 bulk -> 81.00 coupon -> 87.48 with tax
        self.assertEqual(order_total([("10.00", 10)], "PCT10"), Decimal("87.48"))

    def test_unknown_coupon(self):
        with self.assertRaises(ValueError):
            order_total([("10.00", 1)], "BOGUS")

    def test_none_coupon(self):
        self.assertEqual(order_total([("10.00", 1)], None), Decimal("10.80"))


if __name__ == "__main__":
    unittest.main()
