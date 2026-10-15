"""HTTP handlers for the orders service."""
import datetime
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from app.db import connect
from app.errors import ApiError
from app.log import get_logger

log = get_logger(__name__)


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def order_json(db, oid):
    r = db.execute("SELECT * FROM orders WHERE id = ?", (oid,)).fetchone()
    if not r:
        raise ApiError(404, "order_not_found", "no order %s" % oid)
    return dict(r)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, status, obj):
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_body(self):
        n = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            raise ApiError(400, "invalid_request", "body is not JSON")
        if not isinstance(body, dict):
            raise ApiError(400, "invalid_request", "body must be an object")
        return body

    def create_order(self):
        body = self.read_body()
        customer, items = body.get("customer"), body.get("items")
        if not isinstance(customer, str) or not customer or not isinstance(items, list) or not items:
            raise ApiError(400, "invalid_request", "customer and items are required")
        total = 0
        for it in items:
            if not isinstance(it, dict) or not isinstance(it.get("qty"), int) or not isinstance(it.get("price_cents"), int):
                raise ApiError(400, "invalid_request", "each item needs sku, qty, price_cents")
            total += it["qty"] * it["price_cents"]
        cur = self.server.db.execute(
            "INSERT INTO orders (customer, status, total_cents, created_at) VALUES (?, 'pending', ?, ?)",
            (customer, total, now()))
        for it in items:
            self.server.db.execute("INSERT INTO order_items VALUES (?, ?, ?, ?)",
                                   (cur.lastrowid, it.get("sku"), it["qty"], it["price_cents"]))
        log.info("order %s created for %s total_cents=%s", cur.lastrowid, customer, total)
        return 201, order_json(self.server.db, cur.lastrowid)

    def pay_order(self, oid):
        order = order_json(self.server.db, oid)
        if order["status"] != "pending":
            raise ApiError(409, "order_not_payable", "only pending orders can be paid")
        self.server.db.execute("UPDATE orders SET status = 'paid', paid_at = ? WHERE id = ?", (now(), oid))
        log.info("order %s paid", oid)
        return 200, order_json(self.server.db, oid)

    def route(self, method):
        path = self.path.split("?")[0]
        if method == "POST" and path == "/orders":
            return self.create_order()
        if method == "GET" and path == "/orders":
            rows = self.server.db.execute("SELECT id FROM orders ORDER BY id").fetchall()
            return 200, {"orders": [order_json(self.server.db, r[0]) for r in rows]}
        m = re.fullmatch(r"/orders/(\d+)", path)
        if method == "GET" and m:
            return 200, order_json(self.server.db, int(m.group(1)))
        m = re.fullmatch(r"/orders/(\d+)/pay", path)
        if method == "POST" and m:
            return self.pay_order(int(m.group(1)))
        raise ApiError(404, "not_found", "no route")

    def handle_method(self, method):
        try:
            with self.server.lock:
                status, body = self.route(method)
                self.server.db.commit()
            self.send_json(status, body)
        except ApiError as e:
            self.send_json(e.status, e.body())

    def do_GET(self):
        self.handle_method("GET")

    def do_POST(self):
        self.handle_method("POST")


def serve(port, db_path):
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.db = connect(db_path)
    server.lock = threading.RLock()
    log.info("listening on %s", port)
    server.serve_forever()
