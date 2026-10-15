"""Shared helper for hidden HTTP acceptance tests.

Starts the agent-built server exactly as the task contract says
(`python3 <entry> --port <p> --db <path>` from APP_DIR), waits for the port,
and offers a tiny JSON client. Stdlib only.
"""
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request

APP_DIR = os.environ["APP_DIR"]


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class Server:
    def __init__(self, entry, db_path=None):
        self.entry = entry
        self.db = db_path or os.path.join(tempfile.mkdtemp(prefix="bench-db-"), "app.db")
        self.port = None
        self.proc = None

    def start(self):
        self.port = free_port()
        self.proc = subprocess.Popen(
            [sys.executable, self.entry, "--port", str(self.port), "--db", self.db],
            cwd=APP_DIR, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        deadline = time.time() + 15
        while time.time() < deadline:
            if self.proc.poll() is not None:
                raise RuntimeError("server exited: %s" % self.proc.stderr.read().decode()[-800:])
            try:
                socket.create_connection(("127.0.0.1", self.port), timeout=0.3).close()
                return self
            except OSError:
                time.sleep(0.1)
        raise RuntimeError("server did not open port %d" % self.port)

    def stop(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        if self.proc and self.proc.stderr:
            self.proc.stderr.close()

    def req(self, method, path, body=None, token=None, raw=None, headers=None):
        """Return (status, parsed_json_or_text, headers)."""
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        h = {"Content-Type": "application/json"} if data is not None else {}
        if token:
            h["Authorization"] = "Bearer " + token
        h.update(headers or {})
        r = urllib.request.Request("http://127.0.0.1:%d%s" % (self.port, path), data=data, method=method, headers=h)
        try:
            with urllib.request.urlopen(r, timeout=10) as resp:
                status, payload, hdrs = resp.status, resp.read(), resp.headers
        except urllib.error.HTTPError as e:
            status, payload, hdrs = e.code, e.read(), e.headers
        text = payload.decode("utf-8", "replace")
        try:
            return status, (json.loads(text) if text else None), hdrs
        except ValueError:
            return status, text, hdrs


class ServerTest(unittest.TestCase):
    """One fresh server + database per test class."""
    ENTRY = None

    @classmethod
    def setUpClass(cls):
        cls.srv = Server(cls.ENTRY).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.stop()

    def req(self, *a, **kw):
        return self.srv.req(*a, **kw)
