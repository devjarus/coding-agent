"""Reference Trackr (phase 2 complete). Used only to validate the hidden tests."""
import argparse, datetime, hashlib, json, os, re, secrets, sqlite3, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

MOVES = {"open": {"in_progress", "wont_fix"}, "in_progress": {"open", "done"}, "done": {"open"}, "wont_fix": {"open"}}
LOCK = threading.Lock()
PAGE = b"""<!doctype html><html><head><title>Trackr</title></head><body>
<h1>Trackr</h1><form id="login"><label>Username <input name="username"></label>
<label>Password <input name="password" type="password"></label><button>Log in</button></form></body></html>"""


def now():
    return datetime.datetime.utcnow().isoformat() + "Z"


def connect(path):
    c = sqlite3.connect(path, check_same_thread=False)
    c.row_factory = sqlite3.Row
    c.executescript("""
    create table if not exists users(id integer primary key, username text unique, salt text, pw text);
    create table if not exists tokens(token text primary key, user_id int);
    create table if not exists projects(id integer primary key, key text unique, name text, owner text, seq int default 0);
    create table if not exists members(project text, username text, primary key(project, username));
    create table if not exists issues(ref text primary key, project text, number int, title text, description text,
        status text, assignee text, created_by text, created_at text, updated_at text, labels text default '[]');
    create table if not exists comments(id integer primary key, ref text, author text, body text, created_at text);
    create table if not exists labels(project text, name text, color text, primary key(project, name));
    create table if not exists history(id integer primary key, ref text, at text, actor text, field text, frm text, too text);
    """)
    return c


def hashpw(salt, pw):
    return hashlib.pbkdf2_hmac("sha256", pw.encode(), bytes.fromhex(salt), 100000).hex()


class Err(Exception):
    def __init__(self, code, msg):
        self.code, self.msg = code, msg


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send_error(self, code, message=None, explain=None):
        self.out(code, {"error": message or "error"})

    def out(self, code, obj=None, ctype="application/json"):
        body = obj if isinstance(obj, bytes) else (b"" if obj is None else json.dumps(obj).encode())
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        try:
            b = json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            raise Err(400, "invalid json")
        if not isinstance(b, dict):
            raise Err(400, "expected object")
        return b

    def user(self):
        h = self.headers.get("Authorization", "")
        tok = h[7:] if h.startswith("Bearer ") else None
        r = tok and self.db.execute("select u.username from tokens t join users u on u.id=t.user_id where token=?", (tok,)).fetchone()
        if not r:
            raise Err(401, "unauthorized")
        return r["username"]

    def project(self, key, me):
        p = self.db.execute("select * from projects where key=?", (key,)).fetchone()
        if not p:
            raise Err(404, "no such project")
        if p["owner"] != me and not self.db.execute("select 1 from members where project=? and username=?", (key, me)).fetchone():
            raise Err(403, "forbidden")
        return p

    def in_project(self, key, username):
        p = self.db.execute("select owner from projects where key=?", (key,)).fetchone()
        return username == p["owner"] or bool(self.db.execute("select 1 from members where project=? and username=?", (key, username)).fetchone())

    def issue_json(self, r):
        d = {k: r[k] for k in ("ref", "number", "title", "description", "status", "assignee", "created_by", "created_at", "updated_at")}
        d["labels"] = sorted(json.loads(r["labels"] or "[]"))
        return d

    def issue(self, ref, me):
        r = self.db.execute("select * from issues where ref=?", (ref,)).fetchone()
        if not r:
            raise Err(404, "no such issue")
        self.project(r["project"], me)
        return r

    def handle_req(self, method):
        self.db = self.server.db
        u = urlparse(self.path)
        p, q = u.path, parse_qs(u.query)
        if method == "GET" and p == "/":
            return self.out(200, PAGE, "text/html; charset=utf-8")
        if method == "POST" and p == "/api/users":
            b = self.body()
            un, pw = b.get("username"), b.get("password")
            if not isinstance(un, str) or not re.fullmatch(r"[a-z0-9_]{3,20}", un) or not isinstance(pw, str) or len(pw) < 8:
                raise Err(400, "invalid username or password")
            salt = secrets.token_hex(16)
            try:
                cur = self.db.execute("insert into users(username,salt,pw) values(?,?,?)", (un, salt, hashpw(salt, pw)))
            except sqlite3.IntegrityError:
                raise Err(409, "username taken")
            return self.out(201, {"id": cur.lastrowid, "username": un})
        if method == "POST" and p == "/api/login":
            b = self.body()
            r = self.db.execute("select * from users where username=?", (b.get("username"),)).fetchone()
            if not r or not isinstance(b.get("password"), str) or hashpw(r["salt"], b["password"]) != r["pw"]:
                raise Err(401, "bad credentials")
            tok = secrets.token_hex(24)
            self.db.execute("insert into tokens values(?,?)", (tok, r["id"]))
            return self.out(200, {"token": tok})
        if not p.startswith("/api/"):
            raise Err(404, "not found")
        me = self.user()
        if p == "/api/projects":
            if method == "POST":
                b = self.body()
                key, name = b.get("key"), b.get("name")
                if not isinstance(key, str) or not re.fullmatch(r"[A-Z]{2,6}", key) or not isinstance(name, str) or not name.strip():
                    raise Err(400, "invalid project")
                try:
                    cur = self.db.execute("insert into projects(key,name,owner) values(?,?,?)", (key, name, me))
                except sqlite3.IntegrityError:
                    raise Err(409, "duplicate key")
                return self.out(201, {"id": cur.lastrowid, "key": key, "name": name, "owner": me})
            rows = self.db.execute("select * from projects where owner=? or key in (select project from members where username=?) order by key", (me, me))
            return self.out(200, {"items": [{"id": r["id"], "key": r["key"], "name": r["name"], "owner": r["owner"]} for r in rows]})
        m = re.fullmatch(r"/api/projects/([^/]+)/(members|issues|labels)", p)
        if m:
            key, sub = m.groups()
            pr = self.project(key, me)
            if sub == "members" and method == "POST":
                if pr["owner"] != me:
                    raise Err(403, "owner only")
                un = self.body().get("username")
                if not self.db.execute("select 1 from users where username=?", (un,)).fetchone():
                    raise Err(404, "no such user")
                self.db.execute("insert or ignore into members values(?,?)", (key, un))
                mem = [r[0] for r in self.db.execute("select username from members where project=? order by username", (key,))]
                return self.out(201, {"key": key, "members": mem})
            if sub == "labels":
                if method == "POST":
                    b = self.body()
                    name, color = b.get("name"), b.get("color")
                    if not isinstance(name, str) or not 1 <= len(name) <= 20 or not isinstance(color, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
                        raise Err(400, "invalid label")
                    try:
                        self.db.execute("insert into labels values(?,?,?)", (key, name, color.lower()))
                    except sqlite3.IntegrityError:
                        raise Err(409, "duplicate label")
                    return self.out(201, {"name": name, "color": color.lower()})
                rows = self.db.execute("select name,color from labels where project=? order by name", (key,))
                return self.out(200, {"items": [dict(r) for r in rows]})
            if sub == "issues" and method == "POST":
                b = self.body()
                title = b.get("title")
                if not isinstance(title, str) or not title.strip():
                    raise Err(400, "title required")
                asg = b.get("assignee")
                if asg is not None and not self.in_project(key, asg):
                    raise Err(400, "assignee not in project")
                with LOCK:
                    self.db.execute("update projects set seq=seq+1 where key=?", (key,))
                    n = self.db.execute("select seq from projects where key=?", (key,)).fetchone()[0]
                    ts = now()
                    self.db.execute("insert into issues(ref,project,number,title,description,status,assignee,created_by,created_at,updated_at,labels) values(?,?,?,?,?,?,?,?,?,?,'[]')",
                                    ("%s-%d" % (key, n), key, n, title, b.get("description") or "", "open", asg, me, ts, ts))
                return self.out(201, self.issue_json(self.db.execute("select * from issues where ref=?", ("%s-%d" % (key, n),)).fetchone()))
            if sub == "issues" and method == "GET":
                items = [self.issue_json(r) for r in self.db.execute("select * from issues where project=? order by number", (key,))]
                if "status" in q:
                    items = [i for i in items if i["status"] == q["status"][0]]
                if "assignee" in q:
                    items = [i for i in items if i["assignee"] == q["assignee"][0]]
                if "label" in q:
                    items = [i for i in items if q["label"][0] in i["labels"]]
                if "q" in q:
                    s = q["q"][0].lower()
                    items = [i for i in items if s in i["title"].lower() or s in i["description"].lower()]
                page = max(1, int(q.get("page", ["1"])[0]))
                per = max(1, min(50, int(q.get("per_page", ["10"])[0])))
                return self.out(200, {"items": items[(page - 1) * per: page * per], "total": len(items), "page": page, "per_page": per})
        m = re.fullmatch(r"/api/issues/([^/]+)(/comments|/history)?", p)
        if m:
            ref, sub = m.groups()
            r = self.issue(ref, me)
            if sub == "/comments" and method == "POST":
                body = self.body().get("body")
                if not isinstance(body, str) or not body.strip():
                    raise Err(400, "empty comment")
                ts = now()
                cur = self.db.execute("insert into comments(ref,author,body,created_at) values(?,?,?,?)", (ref, me, body, ts))
                return self.out(201, {"id": cur.lastrowid, "author": me, "body": body, "created_at": ts})
            if sub == "/history":
                rows = self.db.execute("select * from history where ref=? order by id", (ref,))
                return self.out(200, {"items": [{"at": h["at"], "actor": h["actor"], "field": h["field"], "from": json.loads(h["frm"]), "to": json.loads(h["too"])} for h in rows]})
            if sub is None and method == "GET":
                d = self.issue_json(r)
                d["comments"] = [dict(c) for c in self.db.execute("select id,author,body,created_at from comments where ref=? order by id", (ref,))]
                return self.out(200, d)
            if sub is None and method == "PATCH":
                b = self.body()
                cur = self.issue_json(r)
                new = dict(cur)
                if "title" in b:
                    if not isinstance(b["title"], str) or not b["title"].strip():
                        raise Err(400, "title required")
                    new["title"] = b["title"]
                if "description" in b:
                    new["description"] = b["description"] or ""
                if "assignee" in b:
                    if b["assignee"] is not None and not self.in_project(r["project"], b["assignee"]):
                        raise Err(400, "assignee not in project")
                    new["assignee"] = b["assignee"]
                if "labels" in b:
                    known = {x[0] for x in self.db.execute("select name from labels where project=?", (r["project"],))}
                    if not isinstance(b["labels"], list) or any(l not in known for l in b["labels"]):
                        raise Err(400, "unknown label")
                    new["labels"] = sorted(set(b["labels"]))
                if "status" in b:
                    st = b["status"]
                    if st not in MOVES:
                        raise Err(400, "unknown status")
                    if st != cur["status"]:
                        if st not in MOVES[cur["status"]]:
                            raise Err(409, "illegal transition")
                        if st == "done":
                            if not new["assignee"]:
                                raise Err(409, "done requires an assignee")
                            owner = self.db.execute("select owner from projects where key=?", (r["project"],)).fetchone()[0]
                            if me not in (new["assignee"], owner):
                                raise Err(403, "only assignee or owner may complete")
                    new["status"] = st
                ts = now()
                for f in ("status", "assignee", "title", "labels"):
                    if new[f] != cur[f]:
                        self.db.execute("insert into history(ref,at,actor,field,frm,too) values(?,?,?,?,?,?)", (ref, ts, me, f, json.dumps(cur[f]), json.dumps(new[f])))
                self.db.execute("update issues set title=?,description=?,assignee=?,status=?,labels=?,updated_at=? where ref=?",
                                (new["title"], new["description"], new["assignee"], new["status"], json.dumps(new["labels"]), ts, ref))
                new["updated_at"] = ts
                return self.out(200, new)
        raise Err(404, "not found")

    def dispatch(self, method):
        try:
            with self.server.dblock:
                self.handle_req(method)
                self.server.db.commit()
        except Err as e:
            self.out(e.code, {"error": e.msg})

    def do_GET(self):
        self.dispatch("GET")

    def do_POST(self):
        self.dispatch("POST")

    def do_PATCH(self):
        self.dispatch("PATCH")


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("--port", type=int, required=True)
    a.add_argument("--db", required=True)
    o = a.parse_args()
    s = ThreadingHTTPServer(("127.0.0.1", o.port), H)
    s.db = connect(o.db)
    s.dblock = threading.RLock()
    s.serve_forever()
