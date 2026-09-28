"""Session 2 — members, under the session-1 conventions."""
import unittest
from libtest import Lib, TS


class Members(Lib):
    def test_feat_create_get(self):
        m = self.ok("POST", "/members", {"name": "Ann", "email": "ann@lib.test"}, 201)
        self.assertEqual((m["name"], m["email"]), ("Ann", "ann@lib.test"))
        self.assertEqual(self.ok("GET", "/members/" + m["id"], status=200)["email"], "ann@lib.test")

    def test_conv_ids_and_timestamps(self):
        m = self.member()
        self.assertId(m["id"])
        self.assertRegex(m["created_at"], TS)

    def test_conv_errors(self):
        self.ok("POST", "/members", {"name": "Bo", "email": "Bo@Lib.test"}, 201)
        self.assertErr(self.req("POST", "/members", {"name": "Bo2", "email": "bo@lib.TEST"}), 409, "conflict")
        self.assertErr(self.req("POST", "/members", {"name": "C", "email": "no-at-sign"}), 400, "validation_error")
        self.assertErr(self.req("POST", "/members", {"name": "C", "email": "@x.test"}), 400, "validation_error")
        self.assertErr(self.req("POST", "/members", {"email": "c@x.test"}), 400, "validation_error")
        self.assertErr(self.req("GET", "/members/mb_missing"), 404, "not_found")

    def test_conv_pagination(self):
        ids = [self.member()["id"] for _ in range(5)]
        got = [m["id"] for m in self.collect("/members")]
        self.assertEqual(got[-5:], ids)
        self.assertErr(self.req("GET", "/members?limit=0"), 400, "validation_error")


if __name__ == "__main__":
    unittest.main()
