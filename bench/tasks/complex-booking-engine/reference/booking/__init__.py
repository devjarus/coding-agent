"""Reference booking engine (phase 2 complete). Used only to validate hidden tests."""
import json, sqlite3, time, uuid

HOLD_SECONDS = 600
MAX_SEATS = 8


class SoldOut(Exception):
    pass


class HoldExpired(Exception):
    pass


class NotFound(Exception):
    pass


class BookingSystem:
    def __init__(self, db_path, clock=time.time):
        self.clock = clock
        self.db = sqlite3.connect(db_path)
        self.db.row_factory = sqlite3.Row
        self.db.executescript("""
        create table if not exists events(id text primary key, name text, capacity int,
            price_cents int default 0, tiers text default '[]', starts_at real);
        create table if not exists holds(id text primary key, event_id text, customer text, seats int,
            idem_key text unique, created real, expires real, state text);
        create table if not exists bookings(id text primary key, hold_id text unique, event_id text, customer text,
            seats int, price_cents int default 0, status text, refund_cents int default 0);
        create table if not exists waitlist(seq integer primary key, event_id text, customer text, seats int);
        """)
        self.db.commit()

    # -- helpers -------------------------------------------------------------
    def _event(self, event_id):
        e = self.db.execute("select * from events where id=?", (event_id,)).fetchone()
        if not e:
            raise NotFound(event_id)
        return e

    def _confirmed(self, event_id):
        return self.db.execute("select coalesce(sum(seats),0) from bookings where event_id=? and status='confirmed'", (event_id,)).fetchone()[0]

    def _held(self, event_id):
        return self.db.execute("select coalesce(sum(seats),0) from holds where event_id=? and state='active'", (event_id,)).fetchone()[0]

    def _avail(self, event_id):
        return self._event(event_id)["capacity"] - self._confirmed(event_id) - self._held(event_id)

    def _tick(self):
        now = self.clock()
        expired = self.db.execute("select distinct event_id from holds where state='active' and expires<=?", (now,)).fetchall()
        self.db.execute("update holds set state='expired' where state='active' and expires<=?", (now,))
        for r in expired:
            self._promote(r[0])
        self.db.commit()

    def _new_hold(self, event_id, customer, seats, idem_key):
        hid = uuid.uuid4().hex
        now = self.clock()
        self.db.execute("insert into holds values(?,?,?,?,?,?,?,?)", (hid, event_id, customer, seats, idem_key, now, now + HOLD_SECONDS, "active"))
        return hid

    def _promote(self, event_id):
        while True:
            head = self.db.execute("select * from waitlist where event_id=? order by seq limit 1", (event_id,)).fetchone()
            if not head or head["seats"] > self._avail(event_id):
                return
            self.db.execute("delete from waitlist where seq=?", (head["seq"],))
            self._new_hold(event_id, head["customer"], head["seats"], None)

    def _price(self, event_id, seats, already):
        e = self._event(event_id)
        bands = json.loads(e["tiers"] or "[]")
        total, pos = 0, already
        for i in range(seats):
            seat_no, cursor, price = pos + i + 1, 0, e["price_cents"]
            for n, p in bands:
                cursor += n
                if seat_no <= cursor:
                    price = p
                    break
            total += price
        return total

    # -- API -----------------------------------------------------------------
    def create_event(self, event_id, name, capacity, price_cents=0, tiers=None, starts_at=None):
        if not isinstance(capacity, int) or capacity < 1:
            raise ValueError("capacity")
        try:
            self.db.execute("insert into events values(?,?,?,?,?,?)", (event_id, name, capacity, price_cents, json.dumps([list(t) for t in (tiers or [])]), starts_at))
        except sqlite3.IntegrityError:
            raise ValueError("duplicate event")
        self.db.commit()

    def available(self, event_id):
        self._tick()
        return self._avail(event_id)

    def hold(self, event_id, customer, seats, idem_key):
        self._tick()
        prior = self.db.execute("select id from holds where idem_key=?", (idem_key,)).fetchone()
        if prior:
            return prior[0]
        self._event(event_id)
        if not isinstance(seats, int) or not 1 <= seats <= MAX_SEATS:
            raise ValueError("seats")
        if seats > self._avail(event_id):
            raise SoldOut(event_id)
        hid = self._new_hold(event_id, customer, seats, idem_key)
        self.db.commit()
        return hid

    def confirm(self, hold_id):
        self._tick()
        h = self.db.execute("select * from holds where id=?", (hold_id,)).fetchone()
        if not h:
            raise NotFound(hold_id)
        b = self.db.execute("select id from bookings where hold_id=?", (hold_id,)).fetchone()
        if b:
            return b[0]
        if h["state"] != "active":
            raise HoldExpired(hold_id)
        price = self._price(h["event_id"], h["seats"], self._confirmed(h["event_id"]))
        bid = uuid.uuid4().hex
        self.db.execute("insert into bookings values(?,?,?,?,?,?,?,0)", (bid, hold_id, h["event_id"], h["customer"], h["seats"], price, "confirmed"))
        self.db.execute("update holds set state='confirmed' where id=?", (hold_id,))
        self.db.commit()
        return bid

    def cancel(self, booking_id):
        self._tick()
        b = self.db.execute("select * from bookings where id=?", (booking_id,)).fetchone()
        if not b:
            raise NotFound(booking_id)
        if b["status"] == "cancelled":
            return 0
        e = self._event(b["event_id"])
        now, refund = self.clock(), b["price_cents"]
        if e["starts_at"] is not None:
            if now <= e["starts_at"] - 7 * 86400:
                refund = b["price_cents"]
            elif now <= e["starts_at"] - 86400:
                refund = b["price_cents"] // 2
            else:
                refund = 0
        self.db.execute("update bookings set status='cancelled', refund_cents=? where id=?", (refund, booking_id))
        self._promote(b["event_id"])
        self.db.commit()
        return refund

    def booking(self, booking_id):
        self._tick()
        b = self.db.execute("select * from bookings where id=?", (booking_id,)).fetchone()
        if not b:
            raise NotFound(booking_id)
        return {"booking_id": b["id"], "event_id": b["event_id"], "customer": b["customer"], "seats": b["seats"],
                "price_cents": b["price_cents"], "status": b["status"], "refund_cents": b["refund_cents"]}

    def quote(self, event_id, seats):
        self._tick()
        return self._price(event_id, seats, self._confirmed(event_id))

    def join_waitlist(self, event_id, customer, seats):
        self._tick()
        self._event(event_id)
        self.db.execute("insert into waitlist(event_id,customer,seats) values(?,?,?)", (event_id, customer, seats))
        self.db.commit()
        return len(self.waitlist(event_id))

    def waitlist(self, event_id):
        return [r[0] for r in self.db.execute("select customer from waitlist where event_id=? order by seq", (event_id,))]

    def holds_for(self, customer):
        self._tick()
        return [r[0] for r in self.db.execute("select id from holds where customer=? and state='active' order by created, rowid", (customer,))]

    def report(self, event_id):
        self._tick()
        e = self._event(event_id)
        return {"event_id": event_id, "capacity": e["capacity"], "confirmed": self._confirmed(event_id),
                "held": self._held(event_id), "available": self._avail(event_id), "waitlist": len(self.waitlist(event_id))}
