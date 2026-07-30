#!/usr/bin/env python3
"""Multi-site GitHub push webhook → `git pull` deployer.

One loopback service behind Caddy serves every sibling site on the box. Each
site's Caddy block reverse-proxies `POST /_deploy` here; the service selects the
target checkout by the (Caddy-set, loopback-trusted) Host header, verifies that
site's HMAC-SHA256 secret, and fast-forwards it on a push to its branch.
Standard-library only, no third-party deps.

Sites are configured in a JSON file (default /etc/webhook-deploy/sites.json),
re-read on every request so adding a site needs no restart:

  {
    "syncengine.earth": {"dir": "/var/www/syncengine", "branch": "main", "secret": "…"},
    "agualila.earth":   {"dir": "/var/www/agualila",   "branch": "main", "secret": "…"}
  }

A leading "www." on the request Host is stripped, so one entry covers apex+www.

Env: CONFIG (config path), PORT (loopback listen port, default 9000).

Security: rejects unknown hosts (404) and any request whose signature does not
match that site's secret (401); only acts on refs/heads/<branch> push events;
binds loopback only; runs `git pull --ff-only` (never a merge/rebase that could
rewrite the tree).
"""
import hashlib
import hmac
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONFIG = os.environ.get("CONFIG", "/etc/webhook-deploy/sites.json")
PORT = int(os.environ.get("PORT", "9000"))
MAX_BODY = 5 * 1024 * 1024  # 5 MB cap on request bodies


def log(msg):
    print(msg, flush=True)


def load_sites():
    try:
        with open(CONFIG) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        log(f"ERROR reading {CONFIG}: {e}")
        return {}


def site_for_host(host):
    host = host.split(":")[0].lower()
    if host.startswith("www."):
        host = host[4:]
    return host, load_sites().get(host)


def verify(secret, body, sig):
    if not sig or not sig.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sig)


def _rev(d):
    return subprocess.run(["git", "-C", d, "rev-parse", "HEAD"],
                          capture_output=True, text=True).stdout.strip()


def _changed_files(d, old, new):
    """Files that changed between two revs (empty on first deploy / no move)."""
    if not old or not new or old == new:
        return []
    r = subprocess.run(["git", "-C", d, "diff", "--name-only", old, new],
                       capture_output=True, text=True)
    return [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]


def run_post_deploy(host, d, changed):
    """Run the site's own deploy/post-deploy.sh (if present + executable) after
    a successful pull. The changed-file list is fed on stdin, one path per line,
    so each repo owns its "if these files changed, restart X / reload Y" logic —
    keeping site-specific deploy steps in the site's repo, not in this service.
    Runs as this service's user (truman); it may sudo -n for allow-listed steps."""
    hook = os.path.join(d, "deploy", "post-deploy.sh")
    if not (os.path.isfile(hook) and os.access(hook, os.X_OK)):
        return True
    log(f"{host}: post-deploy hook ({len(changed)} changed file(s))")
    try:
        r = subprocess.run(["bash", hook], cwd=d, timeout=180,
                           input="\n".join(changed) + "\n",
                           capture_output=True, text=True,
                           env={**os.environ, "DEPLOY_DIR": d, "DEPLOY_HOST": host})
    except subprocess.TimeoutExpired:
        log(f"{host}: post-deploy TIMEOUT")
        return False
    for line in (r.stdout + r.stderr).splitlines():
        if line.strip():
            log(f"  [post-deploy] {line.strip()}")
    log(f"{host}: post-deploy exit={r.returncode}")
    return r.returncode == 0


def deploy(host, cfg):
    d, br = cfg["dir"], cfg.get("branch", "main")
    old = _rev(d)
    log(f"{host}: git -C {d} pull --ff-only origin {br}")
    try:
        r = subprocess.run(["git", "-C", d, "pull", "--ff-only", "origin", br],
                           capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        log(f"{host}: deploy TIMEOUT")
        return False
    for line in (r.stdout + r.stderr).splitlines():
        if line.strip():
            log(f"  {line.strip()}")
    new = _rev(d)
    head = subprocess.run(["git", "-C", d, "log", "--oneline", "-1"],
                          capture_output=True, text=True).stdout.strip()
    log(f"{host}: exit={r.returncode} HEAD={head}")
    if r.returncode != 0:
        return False
    return run_post_deploy(host, d, _changed_files(d, old, new))


class Handler(BaseHTTPRequestHandler):
    def _reply(self, code, msg):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write((msg + "\n").encode())

    def log_message(self, *a):
        pass  # silence default logging; we log our own

    def do_GET(self):
        self._reply(200, "ok")  # health check

    def do_POST(self):
        host, cfg = site_for_host(self.headers.get("Host", ""))
        if not cfg:
            log(f"reject: unknown host {host!r}")
            return self._reply(404, "unknown site")
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > MAX_BODY:
            return self._reply(413, "bad length")
        body = self.rfile.read(n)
        if not verify(cfg["secret"], body, self.headers.get("X-Hub-Signature-256", "")):
            log(f"reject: bad signature for {host}")
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
        want = "refs/heads/" + cfg.get("branch", "main")
        if ref != want:
            log(f"{host}: ignore push to {ref}")
            return self._reply(202, f"ignored ref: {ref}")
        ok = deploy(host, cfg)
        return self._reply(200 if ok else 500, "deployed" if ok else "deploy failed")


if __name__ == "__main__":
    sites = load_sites()
    if not sites:
        log(f"refusing to start: no sites configured in {CONFIG}")
        sys.exit(1)
    log(f"webhook-deploy on 127.0.0.1:{PORT} → sites: {', '.join(sites)}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
