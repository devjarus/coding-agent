"""Hidden acceptance tests — booking engine phase 2 (prices, refunds, groups)."""
import unittest
from booktest import BookTest, booking

DAY = 86400


class Prices(BookTest):
    def setUp(self):
        super().setUp()
        self.bs.create_event("t", "Tiered", 40, price_cents=1000, tiers=[(10, 500), (5, 800)])

    def test_quote_bands(self):
        self.assertEqual(self.bs.quote("t", 2), 1000)
        self.bs.confirm(self.bs.hold("t", "a", 8, "a"))
        self.assertEqual(self.bs.quote("t", 4), 500 * 2 + 800 * 2)   # seats 9-12

    def test_confirm_records_price(self):
        bid = self.bs.confirm(self.bs.hold("t", "a", 3, "a"))
        rec = self.bs.booking(bid)
        self.assertEqual((rec["price_cents"], rec["status"], rec["refund_cents"], rec["seats"], rec["customer"]),
                         (1500, "confirmed", 0, 3, "a"))

    def test_after_bands(self):
        for i in range(2):
            self.bs.confirm(self.bs.hold("t", "f%d" % i, 8, "f%d" % i))  # 16 confirmed
        self.assertEqual(self.bs.quote("t", 1), 1000)

    def test_cancel_reopens_band(self):
        bid = self.bs.confirm(self.bs.hold("t", "a", 8, "a"))
        self.bs.cancel(bid)
        self.assertEqual(self.bs.quote("t", 1), 500)

    def test_default_price_zero(self):
        self.bs.create_event("free", "Free", 5)
        bid = self.bs.confirm(self.bs.hold("free", "a", 2, "z"))
        self.assertEqual(self.bs.booking(bid)["price_cents"], 0)


class Refunds(BookTest):
    def book(self, eid, starts_at):
        self.bs.create_event(eid, "R", 10, price_cents=1001, starts_at=starts_at)
        return self.bs.confirm(self.bs.hold(eid, "a", 1, eid))

    def test_full_refund_7_days(self):
        b = self.book("r1", self.clock.t + 8 * DAY)
        self.assertEqual(self.bs.cancel(b), 1001)
        rec = self.bs.booking(b)
        self.assertEqual((rec["status"], rec["refund_cents"]), ("cancelled", 1001))

    def test_half_refund_rounds_down(self):
        b = self.book("r2", self.clock.t + 2 * DAY)
        self.assertEqual(self.bs.cancel(b), 500)

    def test_no_refund_last_day(self):
        b = self.book("r3", self.clock.t + 3600)
        self.assertEqual(self.bs.cancel(b), 0)

    def test_no_start_full_refund_and_double_cancel(self):
        b = self.book("r4", None)
        self.assertEqual(self.bs.cancel(b), 1001)
        self.assertEqual(self.bs.cancel(b), 0)


class Groups(BookTest):
    def test_eight_ok_nine_not(self):
        self.bs.create_event("g", "Group", 20)
        self.bs.hold("g", "a", 7, "g7")
        self.bs.hold("g", "b", 8, "g8")
        with self.assertRaises(ValueError):
            self.bs.hold("g", "c", 9, "g9")


if __name__ == "__main__":
    unittest.main()
