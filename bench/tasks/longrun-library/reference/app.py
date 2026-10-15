"""Reference library service (all sessions). Used only to validate hidden tests."""
import argparse, datetime, json, math, re, secrets, sqlite3, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, unquote

PAGE_DEFAULT, PAGE_MAX = 50, 200
DAY = 86400
TS_RE = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$")


class ApiErr(Exception):
    def __init__(self, status, code, message):
        self.status, self.code, self.message = status, code, message


def bad(msg):
    return ApiErr(400, "validation_error", msg)


def missing(msg):
    return ApiErr(404, "not_found", msg)


def clash(msg):
    return ApiErr(409, "conflict", msg)


def utcnow():
    return datetime.datetime.now(datetime.timezone.utc)


def fmt(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def parse_ts(v, name):
    if not isinstance(v, str) or not TS_RE.match(v):
        raise bad("%s must be an ISO-8601 UTC timestamp ending in Z" % name)
    try:
        return datetime.datetime.fromisoformat(v[:-1]).replace(tzinfo=datetime.timezone.utc)
    except ValueError:
        raise bad("%s is not a valid timestamp" % name)


def to_dt(s):
    return datetime.datetime.fromisoformat(s[:-1]).replace(tzinfo=datetime.timezone.utc)


def new_id(prefix):
    return "%s_%s" % (prefix, secrets.token_hex(6))


def req_str(body, key):
    v = body.get(key)
    if not isinstance(v, str) or not v.strip():
        raise bad("%s is required" % key)
    return v


SCHEMA = """
create table if not exists branches(seq integer primary key autoincrement, id text unique, code text unique, name text, created_at text);
create table if not exists books(seq integer primary key autoincrement, id text unique, title text, author text, isbn text unique, branch_id text, created_at text);
create table if not exists members(seq integer primary key autoincrement, id text unique, name text, email text, email_lc text unique, created_at text);
create table if not exists loans(seq integer primary key autoincrement, id text unique, book_id text, member_id text, loaned_at text, due_at text, returned_at text, fine_cents int default 0);
create table if not exists payments(seq integer primary key autoincrement, id text unique, member_id text, amount_cents int, created_at text);
create table if not exists reviews(seq integer primary key autoincrement, id text unique, book_id text, member_id text, rating int, text text, created_at text, unique(book_id, member_id));
create table if not exists holds(seq integer primary key autoincrement, id text unique, book_id text, member_id text, created_at text, unique(book_id, member_id));
"""


class Store:
    def __init__(self, path):
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)
        self.lock = threading.Lock()

    def one(self, sql, *a):
        return self.db.execute(sql, a).fetchone()

    def all(self, sql, *a):
        return self.db.execute(sql, a).fetchall()

    def run(self, sql, *a):
        self.db.execute(sql, a)
        self.db.commit()


def page(q, fetch):
    """fetch(limit, offset) -> rows. Cursor is an opaque offset."""
    try:
        limit = int(q.get("limit", [str(PAGE_DEFAULT)])[0])
    except ValueError:
        raise bad("limit must be an integer")
    if not 1 <= limit <= PAGE_MAX:
        raise bad("limit must be between 1 and %d" % PAGE_MAX)
    off = 0
    if "cursor" in q:
        c = q["cursor"][0]
        if not c.isdigit():
            raise bad("invalid cursor")
        off = int(c)
    rows = fetch(limit + 1, off)
    items = rows[:limit]
    return {"items": items, "next_cursor": str(off + limit) if len(rows) > limit else None}


# --- representations -------------------------------------------------------

def book_out(s, r):
    open_loan = s.one("select 1 from loans where book_id=? and returned_at is null", r["id"])
    hold = s.one("select member_id from holds where book_id=? order by seq limit 1", r["id"])
    reserved = hold["member_id"] if (hold and not open_loan) else None
    agg = s.one("select count(*) n, avg(rating) a from reviews where book_id=?", r["id"])
    return {"id": r["id"], "title": r["title"], "author": r["author"], "isbn": r["isbn"],
            "branch_id": r["branch_id"], "created_at": r["created_at"],
            "available": not open_loan and reserved is None, "reserved_for": reserved,
            "review_count": agg["n"], "avg_rating": round(agg["a"], 2) if agg["n"] else None}


def balance(s, mid):
    f = s.one("select coalesce(sum(fine_cents),0) v from loans where member_id=?", mid)["v"]
    p = s.one("select coalesce(sum(amount_cents),0) v from payments where member_id=?", mid)["v"]
    return f - p


def member_out(s, r):
    return {"id": r["id"], "name": r["name"], "email": r["email"], "created_at": r["created_at"],
            "balance_cents": balance(s, r["id"])}


def loan_out(r):
    return {k: r[k] for k in ("id", "book_id", "member_id", "loaned_at", "due_at", "returned_at", "fine_cents")}


def row_out(r, keys):
    return {k: r[k] for k in keys}


# --- handlers ---------------------------------------------------------------

def get_book(s, bid):
    r = s.one("select * from books where id=?", bid)
    if not r:
        raise missing("book not found")
    return r


def get_member(s, mid):
    r = s.one("select * from members where id=?", mid)
    if not r:
        raise missing("member not found")
    return r


def check_branch(s, v):
    if v is None:
        return None
    if not isinstance(v, str) or not s.one("select 1 from branches where id=?", v):
        raise bad("unknown branch_id")
    return v


def create_book(s, q, b):
    title, author = req_str(b, "title"), req_str(b, "author")
    isbn = b.get("isbn")
    if isbn is not None and not (isinstance(isbn, str) and isbn.isdigit() and len(isbn) in (10, 13)):
        raise bad("isbn must be 10 or 13 digits")
    branch = check_branch(s, b.get("branch_id"))
    if isbn and s.one("select 1 from books where isbn=?", isbn):
        raise clash("isbn already exists")
    bid = new_id("bk")
    s.run("insert into books(id,title,author,isbn,branch_id,created_at) values(?,?,?,?,?,?)",
          bid, title, author, isbn, branch, fmt(utcnow()))
    return 201, book_out(s, get_book(s, bid))


def list_books(s, q, b):
    author = q.get("author", [None])[0]
    if author is not None:
        return 200, page(q, lambda l, o: [book_out(s, r) for r in s.all(
            "select * from books where lower(author)=lower(?) order by seq limit ? offset ?", author, l, o)])
    return 200, page(q, lambda l, o: [book_out(s, r) for r in s.all("select * from books order by seq limit ? offset ?", l, o)])


def search_books(s, q, b):
    term = q.get("q", [""])[0]
    if not term:
        raise bad("q is required")
    return 200, page(q, lambda l, o: [book_out(s, r) for r in s.all(
        "select * from books where instr(lower(title), lower(?)) > 0 or instr(lower(author), lower(?)) > 0 "
        "order by seq limit ? offset ?", term, term, l, o)])


def show_book(s, q, b, bid):
    return 200, book_out(s, get_book(s, bid))


def patch_book(s, q, b, bid):
    get_book(s, bid)
    for k in ("title", "author"):
        if k in b:
            s.run("update books set %s=? where id=?" % k, req_str(b, k), bid)
    if "branch_id" in b:
        s.run("update books set branch_id=? where id=?", check_branch(s, b["branch_id"]), bid)
    return 200, book_out(s, get_book(s, bid))


def create_member(s, q, b):
    name, email = req_str(b, "name"), req_str(b, "email")
    local, at, domain = email.partition("@")
    if not (at and local and domain):
        raise bad("email is invalid")
    if s.one("select 1 from members where email_lc=?", email.lower()):
        raise clash("email already exists")
    mid = new_id("mb")
    s.run("insert into members(id,name,email,email_lc,created_at) values(?,?,?,?,?)", mid, name, email, email.lower(), fmt(utcnow()))
    return 201, member_out(s, get_member(s, mid))


def list_members(s, q, b):
    return 200, page(q, lambda l, o: [member_out(s, r) for r in s.all("select * from members order by seq limit ? offset ?", l, o)])


def show_member(s, q, b, mid):
    return 200, member_out(s, get_member(s, mid))


def create_loan(s, q, b):
    bid, mid = b.get("book_id"), b.get("member_id")
    if not isinstance(bid, str) or not isinstance(mid, str):
        raise bad("book_id and member_id are required")
    now = utcnow()
    loaned = now
    if b.get("loaned_at") is not None:
        loaned = parse_ts(b["loaned_at"], "loaned_at")
        if loaned > now:
            raise bad("loaned_at is in the future")
    get_book(s, bid)
    get_member(s, mid)
    if s.one("select 1 from loans where book_id=? and returned_at is null", bid):
        raise clash("book is out on loan")
    hold = s.one("select member_id from holds where book_id=? order by seq limit 1", bid)
    if hold and hold["member_id"] != mid:
        raise clash("book is reserved for another member")
    if s.one("select count(*) n from loans where member_id=? and returned_at is null", mid)["n"] >= 3:
        raise clash("member already has 3 open loans")
    if balance(s, mid) > 0:
        raise clash("member owes money")
    lid = new_id("ln")
    s.run("insert into loans(id,book_id,member_id,loaned_at,due_at,fine_cents) values(?,?,?,?,?,0)",
          lid, bid, mid, fmt(loaned), fmt(loaned + datetime.timedelta(days=14)))
    if hold:
        s.run("delete from holds where book_id=? and member_id=?", bid, mid)
    return 201, loan_out(s.one("select * from loans where id=?", lid))


def return_loan(s, q, b, lid):
    r = s.one("select * from loans where id=?", lid)
    if not r:
        raise missing("loan not found")
    if r["returned_at"]:
        raise clash("loan already returned")
    now = utcnow()
    ret = now
    if b.get("returned_at") is not None:
        ret = parse_ts(b["returned_at"], "returned_at")
        if ret > now:
            raise bad("returned_at is in the future")
        if ret < to_dt(r["loaned_at"]):
            raise bad("returned_at is before loaned_at")
    late = (ret - to_dt(r["due_at"])).total_seconds()
    fine = 25 * math.ceil(late / DAY) if late > 0 else 0
    s.run("update loans set returned_at=?, fine_cents=? where id=?", fmt(ret), fine, lid)
    return 200, loan_out(s.one("select * from loans where id=?", lid))


def member_loans(s, q, b, mid):
    get_member(s, mid)
    return 200, page(q, lambda l, o: [loan_out(r) for r in s.all(
        "select * from loans where member_id=? order by seq limit ? offset ?", mid, l, o)])


PAY_KEYS = ("id", "member_id", "amount_cents", "created_at")


def create_payment(s, q, b, mid):
    get_member(s, mid)
    amt = b.get("amount_cents")
    if not isinstance(amt, int) or isinstance(amt, bool) or amt <= 0 or amt > balance(s, mid):
        raise bad("amount_cents must be a positive integer no larger than the balance")
    pid = new_id("pay")
    s.run("insert into payments(id,member_id,amount_cents,created_at) values(?,?,?,?)", pid, mid, amt, fmt(utcnow()))
    return 201, row_out(s.one("select * from payments where id=?", pid), PAY_KEYS)


def member_payments(s, q, b, mid):
    get_member(s, mid)
    return 200, page(q, lambda l, o: [row_out(r, PAY_KEYS) for r in s.all(
        "select * from payments where member_id=? order by seq limit ? offset ?", mid, l, o)])


REV_KEYS = ("id", "book_id", "member_id", "rating", "text", "created_at")


def create_review(s, q, b, bid):
    mid, rating, text = b.get("member_id"), b.get("rating"), b.get("text")
    if not isinstance(mid, str):
        raise bad("member_id is required")
    if not isinstance(rating, int) or isinstance(rating, bool) or not 1 <= rating <= 5:
        raise bad("rating must be an integer 1-5")
    if text is not None and (not isinstance(text, str) or len(text) > 500):
        raise bad("text must be at most 500 characters")
    get_book(s, bid)
    get_member(s, mid)
    if not s.one("select 1 from loans where book_id=? and member_id=?", bid, mid):
        raise bad("only members who borrowed the book may review it")
    if s.one("select 1 from reviews where book_id=? and member_id=?", bid, mid):
        raise clash("member already reviewed this book")
    rid = new_id("rv")
    s.run("insert into reviews(id,book_id,member_id,rating,text,created_at) values(?,?,?,?,?,?)",
          rid, bid, mid, rating, text, fmt(utcnow()))
    return 201, row_out(s.one("select * from reviews where id=?", rid), REV_KEYS)


def book_reviews(s, q, b, bid):
    get_book(s, bid)
    return 200, page(q, lambda l, o: [row_out(r, REV_KEYS) for r in s.all(
        "select * from reviews where book_id=? order by seq desc limit ? offset ?", bid, l, o)])


BR_KEYS = ("id", "code", "name", "created_at")


def create_branch(s, q, b):
    code, name = b.get("code"), req_str(b, "name")
    if not isinstance(code, str) or not re.fullmatch(r"[A-Z]{2,6}", code):
        raise bad("code must be 2-6 uppercase letters")
    if s.one("select 1 from branches where code=?", code):
        raise clash("branch code exists")
    brid = new_id("br")
    s.run("insert into branches(id,code,name,created_at) values(?,?,?,?)", brid, code, name, fmt(utcnow()))
    return 201, row_out(s.one("select * from branches where id=?", brid), BR_KEYS)


def list_branches(s, q, b):
    return 200, page(q, lambda l, o: [row_out(r, BR_KEYS) for r in s.all("select * from branches order by code limit ? offset ?", l, o)])


def branch_books(s, q, b, brid):
    if not s.one("select 1 from branches where id=?", brid):
        raise missing("branch not found")
    return 200, page(q, lambda l, o: [book_out(s, r) for r in s.all(
        "select * from books where branch_id=? order by seq limit ? offset ?", brid, l, o)])


HOLD_KEYS = ("id", "book_id", "member_id", "created_at")


def create_hold(s, q, b):
    bid, mid = b.get("book_id"), b.get("member_id")
    if not isinstance(bid, str) or not isinstance(mid, str):
        raise bad("book_id and member_id are required")
    get_book(s, bid)
    get_member(s, mid)
    if not s.one("select 1 from loans where book_id=? and returned_at is null", bid):
        raise bad("book is not out on loan")
    if s.one("select 1 from holds where book_id=? and member_id=?", bid, mid):
        raise clash("hold already exists")
    hid = new_id("hd")
    s.run("insert into holds(id,book_id,member_id,created_at) values(?,?,?,?)", hid, bid, mid, fmt(utcnow()))
    return 201, row_out(s.one("select * from holds where id=?", hid), HOLD_KEYS)


def book_holds(s, q, b, bid):
    get_book(s, bid)
    return 200, page(q, lambda l, o: [row_out(r, HOLD_KEYS) for r in s.all(
        "select * from holds where book_id=? order by seq limit ? offset ?", bid, l, o)])


def overdue(s, q, b):
    as_of = parse_ts(q["as_of"][0], "as_of") if "as_of" in q else utcnow()
    rows = [r for r in s.all("select * from loans where returned_at is null order by due_at, seq")
            if to_dt(r["due_at"]) < as_of]
    out = [{"loan_id": r["id"], "book_id": r["book_id"], "member_id": r["member_id"], "due_at": r["due_at"],
            "days_overdue": int((as_of - to_dt(r["due_at"])).total_seconds() // DAY)} for r in rows]
    return 200, page(q, lambda l, o: out[o:o + l])


ID = r"([^/]+)"
ROUTES = [
    ("POST", r"/books", create_book), ("GET", r"/books", list_books),
    ("GET", r"/books/search", search_books),
    ("GET", r"/books/%s" % ID, show_book), ("PATCH", r"/books/%s" % ID, patch_book),
    ("POST", r"/books/%s/reviews" % ID, create_review), ("GET", r"/books/%s/reviews" % ID, book_reviews),
    ("GET", r"/books/%s/holds" % ID, book_holds),
    ("POST", r"/members", create_member), ("GET", r"/members", list_members),
    ("GET", r"/members/%s" % ID, show_member), ("GET", r"/members/%s/loans" % ID, member_loans),
    ("POST", r"/members/%s/payments" % ID, create_payment), ("GET", r"/members/%s/payments" % ID, member_payments),
    ("POST", r"/loans", create_loan), ("POST", r"/loans/%s/return" % ID, return_loan),
    ("POST", r"/branches", create_branch), ("GET", r"/branches", list_branches),
    ("GET", r"/branches/%s/books" % ID, branch_books),
    ("POST", r"/holds", create_hold),
    ("GET", r"/reports/overdue", overdue),
]


class H(BaseHTTPRequestHandler):
    store = None

    def log_message(self, *a):
        pass

    def send(self, status, obj):
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self):
        u = urlparse(self.path)
        q = parse_qs(u.query, keep_blank_values=True)
        try:
            for method, pat, fn in ROUTES:
                m = re.fullmatch(pat, u.path)
                if m and method == self.command:
                    body = {}
                    n = int(self.headers.get("Content-Length") or 0)
                    if n:
                        try:
                            body = json.loads(self.rfile.read(n))
                        except ValueError:
                            raise bad("malformed JSON")
                        if not isinstance(body, dict):
                            raise bad("body must be a JSON object")
                    with self.store.lock:
                        status, out = fn(self.store, q, body, *[unquote(g) for g in m.groups()])
                    return self.send(status, out)
            raise missing("no such endpoint")
        except ApiErr as e:
            self.send(e.status, {"error": {"code": e.code, "message": e.message}})

    do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = handle_any


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--db", required=True)
    a = ap.parse_args()
    H.store = Store(a.db)
    ThreadingHTTPServer(("127.0.0.1", a.port), H).serve_forever()


if __name__ == "__main__":
    main()
