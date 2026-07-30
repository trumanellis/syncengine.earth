# Auto-deploy for the sibling sites

Several sites (syncengine.earth, agualila.earth, …) are served by **Caddy** from
git checkouts under `/var/www/` on the relay box (`refuge-relay`,
`89.167.41.185`). GitHub is only the `origin`. One shared webhook service
turns a `git push` into a live deploy for whichever site it belongs to.

## How a change goes live

```
git push ─▶ GitHub ─push webhook─▶ https://<site>/_deploy ─▶ Caddy
                                                               │ reverse_proxy
                                                    127.0.0.1:9000  webhook.py
                                                               │ (picks site by Host,
                                                               │  verifies that site's secret)
                                              git -C /var/www/<site> pull --ff-only
```

Pushing is all you do. **Watch any deploy:**
`ssh refuge-relay 'journalctl -u webhook-deploy -f'`

## Per-site post-deploy hooks (optional)

After a successful pull, `webhook.py` diffs old→new HEAD and, if the site's repo
has an executable `deploy/post-deploy.sh`, runs it with the changed files on
stdin (one repo-relative path per line; cwd is the checkout root). This keeps
"if these files changed, do X" logic in each site's own repo — the service stays
generic. A non-zero hook exit makes the deploy report failure (500 → visible as a
failed GitHub delivery). Sites without the script are unaffected.

The hook runs **unprivileged** — this unit is `NoNewPrivileges=true`, so it can't
sudo, on purpose. A hook that needs a privileged step (restart a service, touch
`/etc/…`) should not hold root; instead it enqueues a request that a separate
root unit applies. templesofrefuge does this: its hook writes a fixed-token
`.deploy-request`, and a root `tor-post-deploy.path` + `.service` run a fixed
helper (`/usr/local/bin/tor-post-deploy`, installed out of band, not from the
repo) that performs only its hardcoded actions. See
`templesofrefuge.earth/infra/tor-post-deploy.*` for the pattern.

## Components (one service, N sites)

| Where | What |
|-------|------|
| `deploy/webhook.py` | Multi-site receiver. Routes by Host header, per-site secret. Runs from the syncengine checkout. |
| `deploy/webhook-deploy.service` | systemd unit → `/etc/systemd/system/`. Add each site's dir to `ReadWritePaths`. |
| `deploy/Caddyfile.snippet` | Reference: every site block gets the same `/_deploy` handler → `127.0.0.1:9000`. |
| `/etc/webhook-deploy/sites.json` | **Not in git.** Maps `host → {dir, branch, secret}`, chmod 600. |
| GitHub repo webhook (per site) | Points at `https://<site>/_deploy`, content-type `json`, that site's secret. |

`sites.json` (on the box only):

```json
{
  "syncengine.earth":     {"dir": "/var/www/syncengine",     "branch": "main", "secret": "…"},
  "agualila.earth":       {"dir": "/var/www/agualila",       "branch": "main", "secret": "…"},
  "templesofrefuge.earth": {"dir": "/var/www/templesofrefuge", "branch": "main", "secret": "…"}
}
```

## Add another sibling site

1. Make sure `/var/www/<site>` is a git checkout of its repo on the deploy branch.
2. Add an entry to `/etc/webhook-deploy/sites.json` with a fresh
   `openssl rand -hex 32` secret; add its dir to `ReadWritePaths` in the unit
   and `sudo systemctl restart webhook-deploy`.
3. Add the `/_deploy` handler to its Caddy block (see snippet); `sudo caddy
   validate` then `sudo systemctl reload caddy`.
4. Create the GitHub webhook:
   ```bash
   export SECRET=…   # same value as in sites.json
   python3 -c 'import os,json,sys;json.dump({"name":"web","active":True,"events":["push"],"config":{"url":"https://<site>/_deploy","content_type":"json","secret":os.environ["SECRET"],"insecure_ssl":"0"}},sys.stdout)' \
     | gh api repos/<owner>/<repo>/hooks --input -
   ```

## Manual deploy / fallback

`./scripts/deploy.sh` (in the syncengine repo) pushes and then SSHes in to
`git pull --ff-only` directly, for when the webhook is down.

## Rotating a site's secret

```bash
NEW=$(openssl rand -hex 32)
# update sites.json on the box (jq) then restart:
ssh refuge-relay "sudo python3 -c \"import json;p='/etc/webhook-deploy/sites.json';d=json.load(open(p));d['<site>']['secret']='$NEW';json.dump(d,open(p,'w'))\" && sudo systemctl restart webhook-deploy"
gh api -X PATCH repos/<owner>/<repo>/hooks/<HOOK_ID> --input - <<< "$(SECRET=$NEW python3 -c 'import os,json,sys;json.dump({"config":{"url":"https://<site>/_deploy","content_type":"json","secret":os.environ["SECRET"]}},sys.stdout)')"
```

Find `<HOOK_ID>` with `gh api repos/<owner>/<repo>/hooks --jq '.[].id'`.
