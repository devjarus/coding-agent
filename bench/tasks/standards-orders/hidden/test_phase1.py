"""Hidden tests — standards-orders. Functional behavior + the repo's written standards."""
import glob, hashlib, os, re, unittest
from apptest import ServerTest

APP = os.environ["APP_DIR"]
SEED_MIGRATION_SHA = "81b3443097c8d5452fd9b2e7e9a2027cabe70fb0aca1cfd0dd57e32d0121b6bd"
SEED_LOG_INFO_CALLS = 4


def read(rel):
    with open(os.path.join(APP, rel)) as fh:
        return fh.read()


class Cancel(ServerTest):
    ENTRY = "run.py"

    def order(self, customer="c"):
        return self.req("POST", "/orders", {"customer": customer, "items": [{"sku": "s", "qty": 2, "price_cents": 250}]})[1]

    def test_cancel_pending(self):
        o = self.order()
        s, b, _ = self.req("POST", "/orders/%d/cancel" % o["id"], {"reason": "no longer needed"})
        self.assertEqual((s, b["status"], b["cancel_reason"], b["total_cents"]), (200, "cancelled", "no longer needed", 500))
        self.assertTrue(b.get("cancelled_at"))

    def test_only_pending(self):
        o = self.order()
        self.req("POST", "/orders/%d/pay" % o["id"])
        s, b, _ = self.req("POST", "/orders/%d/cancel" % o["id"], {"reason": "x"})
        self.assertEqual(s, 409)
        self.assertEqual(b, {"type": "error", "code": "order_not_cancellable", "message": b.get("message")})
        self.assertIsInstance(b.get("message"), str)

    def test_reason_required(self):
        o = self.order()
        for body in ({}, {"reason": ""}):
            s, b, _ = self.req("POST", "/orders/%d/cancel" % o["id"], body)
            self.assertEqual(s, 400)
            self.assertEqual(b.get("type"), "error")

    def test_unknown_order(self):
        s, b, _ = self.req("POST", "/orders/99999/cancel", {"reason": "x"})
        self.assertEqual((s, b.get("code")), (404, "order_not_found"))

    def test_list_hides_cancelled(self):
        a, c = self.order("keep"), self.order("drop")
        self.req("POST", "/orders/%d/cancel" % c["id"], {"reason": "x"})
        ids = [o["id"] for o in self.req("GET", "/orders")[1]["orders"]]
        self.assertIn(a["id"], ids)
        self.assertNotIn(c["id"], ids)
        ids_all = [o["id"] for o in self.req("GET", "/orders?include_cancelled=true")[1]["orders"]]
        self.assertIn(c["id"], ids_all)


class Standards(unittest.TestCase):
    """AGENTS.md rules 1-6, checked mechanically."""

    def test_existing_migration_untouched(self):
        with open(os.path.join(APP, "migrations", "001_init.sql"), "rb") as fh:
            self.assertEqual(hashlib.sha256(fh.read()).hexdigest(), SEED_MIGRATION_SHA)

    def test_new_numbered_migration(self):
        names = sorted(os.path.basename(p) for p in glob.glob(os.path.join(APP, "migrations", "*.sql")))
        self.assertTrue(any(re.fullmatch(r"002_[a-z0-9_]+\.sql", n) for n in names), names)

    def test_no_print_in_app(self):
        for p in glob.glob(os.path.join(APP, "app", "**", "*.py"), recursive=True):
            self.assertNotRegex(open(p).read(), r"(^|[^.\w])print\(", p)

    def test_state_change_is_logged(self):
        n = sum(len(re.findall(r"log\.info\(", open(p).read())) for p in glob.glob(os.path.join(APP, "app", "**", "*.py"), recursive=True))
        self.assertGreater(n, SEED_LOG_INFO_CALLS)

    def test_docs_updated(self):
        api = read("docs/API.md")
        self.assertIn("/cancel", api)
        self.assertIn("order_not_cancellable", api)

    def test_changelog_unreleased_entry(self):
        log = read("CHANGELOG.md")
        unreleased = log.split("## Unreleased", 1)[1].split("\n## ", 1)[0]
        self.assertRegex(unreleased.lower(), r"cancel")

    def test_endpoint_has_tests(self):
        found = [p for p in glob.glob(os.path.join(APP, "tests", "test_*.py")) if "cancel" in open(p).read()]
        self.assertTrue(found, "no tests/test_*.py covers cancel")


if __name__ == "__main__":
    unittest.main()
