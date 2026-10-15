"""Shared fixtures for the booking hidden tests."""
import os, sys, tempfile, unittest

sys.path.insert(0, os.environ["APP_DIR"])
import booking  # noqa: E402


class Clock:
    def __init__(self, t=1_000_000.0):
        self.t = t

    def __call__(self):
        return self.t

    def advance(self, s):
        self.t += s


class BookTest(unittest.TestCase):
    def setUp(self):
        self.db = os.path.join(tempfile.mkdtemp(prefix="bench-book-"), "b.db")
        self.clock = Clock()
        self.bs = booking.BookingSystem(self.db, clock=self.clock)
