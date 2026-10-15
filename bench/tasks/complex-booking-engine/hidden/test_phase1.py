"""Hidden acceptance tests — booking engine phase 1 (also the phase-2 regression suite)."""
import json, os, subprocess, sys, unittest
from booktest import BookTest, Clock, booking


class Events(BookTest):
    def test_create_and_available(self):
        self.bs.create_event("e1", "Show", 10)
        self.assertEqual(self.bs.available("e1"), 10)
        with self.assertRaises(ValueError):
            self.bs.create_event("e1", "Again", 5)
        with self.assertRaises(booking.NotFound):
            self.bs.available("nope")


class Holds(BookTest):
    def setUp(self):
        super().setUp()
        self.bs.create_event("e", "Gig", 10)

    def test_hold_reduces_availability(self):
        self.bs.hold("e", "ann", 4, "k1")
        self.assertEqual(self.bs.available("e"), 6)

    def test_seat_limits(self):
        for bad in (0, 9):
            with self.assertRaises(ValueError):
                self.bs.hold("e", "ann", bad, "bad%d" % bad)
        self.bs.hold("e", "ann", 6, "six")

    def test_sold_out(self):
        self.bs.hold("e", "ann", 6, "a")
        with self.assertRaises(booking.SoldOut):
            self.bs.hold("e", "bob", 5, "b")

    def test_unknown_event(self):
        with self.assertRaises(booking.NotFound):
            self.bs.hold("zzz", "ann", 1, "x")

    def test_idempotent(self):
        h1 = self.bs.hold("e", "ann", 3, "same")
        h2 = self.bs.hold("e", "ann", 3, "same")
        self.assertEqual(h1, h2)
        self.assertEqual(self.bs.available("e"), 7)

    def test_expiry(self):
        h = self.bs.hold("e", "ann", 5, "exp")
        self.clock.advance(599)
        self.assertEqual(self.bs.available("e"), 5)
        self.clock.advance(2)
        self.assertEqual(self.bs.available("e"), 10)
        with self.assertRaises(booking.HoldExpired):
            self.bs.confirm(h)

    def test_holds_for(self):
        a = self.bs.hold("e", "ann", 1, "a1")
        b = self.bs.hold("e", "ann", 1, "a2")
        self.bs.hold("e", "bob", 1, "b1")
        self.assertEqual(self.bs.holds_for("ann"), [a, b])


class Bookings(BookTest):
    def setUp(self):
        super().setUp()
        self.bs.create_event("e", "Gig", 5)

    def test_confirm_and_cancel(self):
        h = self.bs.hold("e", "ann", 3, "c1")
        b = self.bs.confirm(h)
        self.assertEqual(self.bs.confirm(h), b)
        self.clock.advance(10_000)            # confirmed seats never expire
        self.assertEqual(self.bs.available("e"), 2)
        self.bs.cancel(b)
        self.bs.cancel(b)                      # second cancel is a no-op
        self.assertEqual(self.bs.available("e"), 5)

    def test_unknown_ids(self):
        with self.assertRaises(booking.NotFound):
            self.bs.confirm("nope")
        with self.assertRaises(booking.NotFound):
            self.bs.cancel("nope")


class Waitlist(BookTest):
    def setUp(self):
        super().setUp()
        self.bs.create_event("w", "Hot", 4)
        self.b = self.bs.confirm(self.bs.hold("w", "first", 4, "all"))

    def test_positions(self):
        self.assertEqual(self.bs.join_waitlist("w", "x", 2), 1)
        self.assertEqual(self.bs.join_waitlist("w", "y", 1), 2)
        self.assertEqual(self.bs.waitlist("w"), ["x", "y"])

    def test_promotion_on_cancel(self):
        self.bs.join_waitlist("w", "x", 2)
        self.bs.join_waitlist("w", "y", 2)
        self.bs.cancel(self.b)
        self.assertEqual(self.bs.waitlist("w"), [])
        self.assertEqual(len(self.bs.holds_for("x")), 1)
        self.assertEqual(len(self.bs.holds_for("y")), 1)
        self.assertEqual(self.bs.available("w"), 0)

    def test_strict_fifo(self):
        self.bs.cancel(self.b)
        big = self.bs.confirm(self.bs.hold("w", "big", 3, "b3"))   # 1 seat left
        self.bs.join_waitlist("w", "needs2", 2)
        self.bs.join_waitlist("w", "needs1", 1)
        self.bs.available("w")
        self.assertEqual(self.bs.waitlist("w"), ["needs2", "needs1"])   # head doesn't fit -> nobody skips
        self.assertEqual(self.bs.holds_for("needs1"), [])
        self.bs.cancel(big)
        self.assertEqual(self.bs.waitlist("w"), [])

    def test_promotion_on_expiry_and_promoted_hold_expires(self):
        self.bs.cancel(self.b)
        self.bs.hold("w", "slow", 4, "slow")
        self.bs.join_waitlist("w", "x", 4)
        self.clock.advance(601)
        self.assertEqual(self.bs.available("w"), 0)       # slow expired, x promoted
        self.assertEqual(len(self.bs.holds_for("x")), 1)
        self.clock.advance(601)
        self.assertEqual(self.bs.available("w"), 4)       # x's promoted hold expires too


class Persistence(BookTest):
    def test_new_instance_sees_state(self):
        self.bs.create_event("p", "Persist", 3)
        self.bs.confirm(self.bs.hold("p", "ann", 2, "p1"))
        again = booking.BookingSystem(self.db, clock=Clock(self.clock.t))
        self.assertEqual(again.available("p"), 1)

    def test_cli_report(self):
        self.bs.create_event("r", "Report", 10)
        self.bs.confirm(self.bs.hold("r", "ann", 3, "r1"))
        self.bs.hold("r", "bob", 2, "r2")
        out = subprocess.run([sys.executable, "-m", "booking", "report", self.db, "r"], cwd=os.environ["APP_DIR"],
                             capture_output=True, text=True, timeout=30)
        d = json.loads(out.stdout)
        self.assertEqual((d["event_id"], d["capacity"], d["confirmed"], d["waitlist"]), ("r", 10, 3, 0))
        self.assertIn(d["held"], (2, 0))          # the CLI uses the real clock; the hold may have "expired"
        self.assertEqual(d["available"], 10 - 3 - d["held"])


if __name__ == "__main__":
    unittest.main()
