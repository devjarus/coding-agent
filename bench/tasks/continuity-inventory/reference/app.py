"""Reference inventory service (all phases). Used only to validate hidden tests."""
import argparse, base64, datetime, json, re, sqlite3, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


class ApiErr(Exception):
    def __init__(self, status, code, message):
        self.status, self.code, self.message = status, code, message


def connect(path):
    c = sqlite3.connect(path, check_same_thread=False)
    c.row_factory = sqlite3.Row
    c.executescript("""
    create table if not exists items(sku text primary key, name text, price_cents int, created_at text, low_stock_threshold int);
    create table if not exists warehouses(code text primary key, name text, created_at text);
    create table if not exists stock(sku text, code text, qty int, primary key(sku, code));
    create table if not exists movements(id integer primary key, sku text, warehouse text, delta int, qty_after int, at text);
    """)
    return c


def enc(v):
    return base64.urlsafe_b64encode(str(v).encode()).decode()


def dec(c):
    try:
        return base64.urlsafe_b64decode(c.encode()).decode()
    except Exception:
        raise ApiErr(400, "validation_error", "bad cursor")


def page(rows, key, q):
    try:
        limit = int(q.get("limit", ["20"])[0])
    except ValueError:
        raise ApiErr(400, "validation_error", "bad limit")
    limit = max(1, min(limit, 100))
    if "cursor" in q:
        after = dec(q["cursor"][0])
        rows = [r for r in rows if str(key(r)) > after] if not isinstance(key(rows[0]) if rows else "", int) else [r for r in rows if key(r) > int(after)]
    items = rows[:limit]
    nxt = enc(key(items[-1])) if len(rows) > limit else None
    return {"items": items, "next_cursor": nxt}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def out(self, status, obj=None):
        body = b"" if obj is None else json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_error(self, code, message=None, explain=None):
        self.out(code, {"error": {"code": "not_found" if code == 404 else "method_not_allowed" if code in (405, 501) else "error", "message": message or "error"}})

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        try:
            b = json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            raise ApiErr(400, "validation_error", "invalid json")
        if not isinstance(b, dict):
            raise ApiErr(400, "validation_error", "expected object")
        return b

    def item(self, sku):
        r = self.db.execute("select * from items where sku=?", (sku,)).fetchone()
        if not r:
            raise ApiErr(404, "not_found", "no such item")
        stock = {s["code"]: s["qty"] for s in self.db.execute("select code, qty from stock where sku=? order by code", (sku,))}
        return {"sku": r["sku"], "name": r["name"], "price_cents": r["price_cents"], "created_at": r["created_at"],
                "stock": stock, "total_qty": sum(stock.values()), "low_stock_threshold": r["low_stock_threshold"]}

    def route(self, method):
        self.db = self.server.db
        u = urlparse(self.path)
        p, q = u.path, parse_qs(u.query)
        if p == "/items" and method == "POST":
            b = self.body()
            sku, name, price = b.get("sku"), b.get("name"), b.get("price_cents")
            if not isinstance(sku, str) or not sku or not isinstance(name, str) or not name.strip() \
                    or not isinstance(price, int) or isinstance(price, bool) or price < 0:
                raise ApiErr(400, "validation_error", "sku, name and non-negative integer price_cents are required")
            try:
                self.db.execute("insert into items(sku,name,price_cents,created_at) values(?,?,?,?)", (sku, name, price, now()))
            except sqlite3.IntegrityError:
                raise ApiErr(409, "conflict", "sku exists")
            return self.out(201, self.item(sku))
        if p == "/items" and method == "GET":
            rows = [self.item(r[0]) for r in self.db.execute("select sku from items order by sku")]
            return self.out(200, page(rows, lambda r: r["sku"], q))
        m = re.fullmatch(r"/items/([^/]+)", p)
        if m and method == "GET":
            return self.out(200, self.item(m.group(1)))
        if m and method == "PATCH":
            sku = m.group(1)
            self.item(sku)
            b = self.body()
            if "name" in b:
                if not isinstance(b["name"], str) or not b["name"].strip():
                    raise ApiErr(400, "validation_error", "bad name")
                self.db.execute("update items set name=? where sku=?", (b["name"], sku))
            if "price_cents" in b:
                v = b["price_cents"]
                if not isinstance(v, int) or isinstance(v, bool) or v < 0:
                    raise ApiErr(400, "validation_error", "bad price_cents")
                self.db.execute("update items set price_cents=? where sku=?", (v, sku))
            if "low_stock_threshold" in b:
                v = b["low_stock_threshold"]
                if v is not None and (not isinstance(v, int) or isinstance(v, bool) or v < 0):
                    raise ApiErr(400, "validation_error", "bad low_stock_threshold")
                self.db.execute("update items set low_stock_threshold=? where sku=?", (v, sku))
            return self.out(200, self.item(sku))
        if p == "/warehouses" and method == "POST":
            b = self.body()
            code, name = b.get("code"), b.get("name")
            if not isinstance(code, str) or not re.fullmatch(r"[A-Z0-9]{2,10}", code) or not isinstance(name, str) or not name.strip():
                raise ApiErr(400, "validation_error", "code (2-10 uppercase letters/digits) and name are required")
            try:
                ts = now()
                self.db.execute("insert into warehouses values(?,?,?)", (code, name, ts))
            except sqlite3.IntegrityError:
                raise ApiErr(409, "conflict", "warehouse exists")
            return self.out(201, {"code": code, "name": name, "created_at": ts})
        if p == "/warehouses" and method == "GET":
            rows = [dict(r) for r in self.db.execute("select code,name,created_at from warehouses order by code")]
            return self.out(200, page(rows, lambda r: r["code"], q))
        m = re.fullmatch(r"/items/([^/]+)/stock/([^/]+)", p)
        if m and method == "PUT":
            sku, code = m.groups()
            self.item(sku)
            if not self.db.execute("select 1 from warehouses where code=?", (code,)).fetchone():
                raise ApiErr(404, "not_found", "no such warehouse")
            qty = self.body().get("qty")
            if not isinstance(qty, int) or isinstance(qty, bool) or qty < 0:
                raise ApiErr(400, "validation_error", "qty must be a non-negative integer")
            old = self.db.execute("select qty from stock where sku=? and code=?", (sku, code)).fetchone()
            old = old[0] if old else 0
            self.db.execute("insert or replace into stock values(?,?,?)", (sku, code, qty))
            if qty != old:
                self.db.execute("insert into movements(sku,warehouse,delta,qty_after,at) values(?,?,?,?,?)", (sku, code, qty - old, qty, now()))
            return self.out(200, {"sku": sku, "warehouse": code, "qty": qty})
        m = re.fullmatch(r"/items/([^/]+)/movements", p)
        if m and method == "GET":
            self.item(m.group(1))
            rows = [dict(r) for r in self.db.execute("select id,sku,warehouse,delta,qty_after,at from movements where sku=? order by id", (m.group(1),))]
            return self.out(200, page(rows, lambda r: r["id"], q))
        if p == "/alerts/low-stock" and method == "GET":
            rows = []
            for r in self.db.execute("select sku from items where low_stock_threshold is not null order by sku"):
                it = self.item(r[0])
                if it["total_qty"] < it["low_stock_threshold"]:
                    rows.append({"sku": it["sku"], "name": it["name"], "total_qty": it["total_qty"], "low_stock_threshold": it["low_stock_threshold"]})
            return self.out(200, page(rows, lambda r: r["sku"], q))
        raise ApiErr(404, "not_found", "no such route")

    def dispatch(self, method):
        try:
            with self.server.lock:
                self.route(method)
                self.server.db.commit()
        except ApiErr as e:
            self.out(e.status, {"error": {"code": e.code, "message": e.message}})

    def do_GET(self):
        self.dispatch("GET")

    def do_POST(self):
        self.dispatch("POST")

    def do_PATCH(self):
        self.dispatch("PATCH")

    def do_PUT(self):
        self.dispatch("PUT")


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("--port", type=int, required=True)
    a.add_argument("--db", required=True)
    o = a.parse_args()
    s = ThreadingHTTPServer(("127.0.0.1", o.port), H)
    s.db, s.lock = connect(o.db), threading.RLock()
    s.serve_forever()
