# Deploying syncengine.earth

The live site is **not** GitHub Pages. `www.syncengine.earth` resolves to the
relay box (`refuge-relay`, Hetzner/Helsinki, `89.167.41.185`), where **Caddy**
serves static files from a git checkout at `/var/www/syncengine`. GitHub is
only the `origin` remote.

## How a change goes live

```
git push  ──▶  GitHub  ──webhook POST /_deploy──▶  Caddy  ──▶  webhook.py
                                                                  │
                                              git -C /var/www/syncengine
                                                   pull --ff-only origin main
```

1. You push to `main`.
2. GitHub sends a signed `push` webhook to `https://syncengine.earth/_deploy`.
3. Caddy reverse-proxies it to `webhook.py` on `127.0.0.1:9000`.
4. `webhook.py` verifies the HMAC signature, checks the ref is `refs/heads/main`,
   and fast-forwards the checkout. Caddy serves the new files immediately (no
   reload — it is a static file server).

Pushing is all you normally do. **Watch a deploy:**
`ssh refuge-relay 'journalctl -u syncengine-webhook -f'`

## Manual deploy / fallback

If the webhook is down, `./scripts/deploy.sh` pushes and then SSHes in to
`git pull --ff-only` directly. Same end state.

## Components

| Where | What |
|-------|------|
| `deploy/webhook.py` | The receiver. Runs from the checkout; updates with the repo. |
| `deploy/syncengine-webhook.service` | systemd unit → installed at `/etc/systemd/system/`. |
| `deploy/Caddyfile.snippet` | Reference copy of the site block in `/etc/caddy/Caddyfile`. |
| `/etc/syncengine-deploy.env` | **Not in git.** Holds `DEPLOY_SECRET` (chmod 600). |
| GitHub repo webhook | Points at `/_deploy`, content-type `json`, with the shared secret. |

## Rotating the deploy secret

```bash
NEW=$(openssl rand -hex 32)
ssh refuge-relay "sudo sed -i 's/^DEPLOY_SECRET=.*/DEPLOY_SECRET=$NEW/' /etc/syncengine-deploy.env && sudo systemctl restart syncengine-webhook"
gh api -X PATCH "repos/trumanellis/syncengine.earth/hooks/<HOOK_ID>" -f config.secret="$NEW" -f config.url=https://syncengine.earth/_deploy -f config.content_type=json
```

Find `<HOOK_ID>` with `gh api repos/trumanellis/syncengine.earth/hooks --jq '.[].id'`.

## First-time install (already done, kept for reference)

```bash
# on refuge-relay, as truman:
printf 'DEPLOY_SECRET=%s\nSITE_DIR=/var/www/syncengine\nDEPLOY_BRANCH=main\nPORT=9000\n' \
  "$(openssl rand -hex 32)" | sudo tee /etc/syncengine-deploy.env >/dev/null
sudo chmod 600 /etc/syncengine-deploy.env
sudo cp /var/www/syncengine/deploy/syncengine-webhook.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now syncengine-webhook
# add the /_deploy handler to the site block in /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile && sudo systemctl reload caddy
# then create the GitHub webhook with the same DEPLOY_SECRET (config.url=/_deploy)
```
