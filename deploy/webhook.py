#!/usr/bin/env python3
"""Minimal GitHub push webhook → `git pull` for syncengine.earth.

Listens on 127.0.0.1:PORT; Caddy reverse-proxies POST /_deploy here. On a
signature-verified push to the deploy branch it fast-forwards the live
checkout that Caddy serves. Standard-library only, no third-party deps.

Configured entirely via environment (see /etc/syncengine-deploy.env):
  DEPLOY_SECRET   shared secret configured on the GitHub webhook (required)
  SITE_DIR        git checkout to update           (default /var/www/syncengine)
  DEPLOY_BRANCH   branch that triggers a deploy    (default main)
  PORT            loopback listen port             (default 9000)

Security posture: rejects any request whose HMAC-SHA256 signature does not
match DEPLOY_SECRET, only acts on refs/heads/$DEPLOY_BRANCH push events, binds
loopback only, and runs `git pull --ff-only` (never a merge/rebase that could
rewrite the working tree). It refuses to start if DEPLOY_SECRET is empty.
"""
import hashlib
import hmac
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET = os.environ.get("DEPLOY_SECRET", "").encode()
SITE_DIR = os.environ.get("SITE_DIR", "/var/www/syncengine")
BRANCH = os.environ.get("DEPLOY_BRANCH", "main")
PORT = int(os.environ.get("PORT", "9000"))
MAX_BODY = 5 * 1024 * 1024  # 5 MB cap on request bodies


def log(msg):
    print(msg, flush=True)


def verify(body, sig_header):
    if not SECRET:
        log("ERROR: DEPLOY_SECRET not set; refusing request")
        return False
    if not sig_header or not sig_header.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(SECRET, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sig_header)


def deploy():
    log(f"deploy: git -C {SITE_DIR} pull --ff-only origin {BRANCH}")
    try:
        r = subprocess.run(
            ["git", "-C", SITE_DIR, "pull", "--ff-only", "origin", BRANCH],
            capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        log("deploy: TIMEOUT")
        return False
    if r.stdout.strip():
        log(r.stdout.strip())
    if r.stderr.strip():
        log(r.stderr.strip())
    head = subprocess.run(["git", "-C", SITE_DIR, "log", "--oneline", "-1"],
                          capture_output=True, text=True).stdout.strip()
    log(f"deploy: exit={r.returncode} HEAD={head}")
    return r.returncode == 0


class Handler(BaseHTTPRequestHandler):
    def _reply(self, code, msg):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write((msg + "\n").encode())

    def log_message(self, *a):
        pass  # silence default per-request stderr logging; we log our own

    def do_GET(self):
        self._reply(200, "ok")  # health check

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BODY:
            return self._reply(413, "bad length")
        body = self.rfile.read(length)
        if not verify(body, self.headers.get("X-Hub-Signature-256", "")):
            log("reject: bad or missing signature")
            return self._reply(401, "bad signature")
        event = self.headers.get("X-GitHub-Event", "")
        if event == "ping":
            return self._reply(200, "pong")
        if event != "push":
            return self._reply(202, f"ignored event: {event}")
        try:
            ref = json.loads(body).get("ref", "")
        except json.JSONDecodeError:
            return self._reply(400, "bad json")
        if ref != f"refs/heads/{BRANCH}":
            log(f"ignore push to {ref}")
            return self._reply(202, f"ignored ref: {ref}")
        ok = deploy()
        return self._reply(200 if ok else 500,
                           "deployed" if ok else "deploy failed")


if __name__ == "__main__":
    if not SECRET:
        log("refusing to start: DEPLOY_SECRET is empty")
        sys.exit(1)
    log(f"webhook listening on 127.0.0.1:{PORT} → {SITE_DIR} ({BRANCH})")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
