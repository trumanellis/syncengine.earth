#!/usr/bin/env bash
# deploy.sh — publish syncengine.earth.
#
# The live site is served by Caddy from a git checkout on the relay box
# (refuge-relay:/var/www/syncengine); GitHub is only the origin. A push
# normally auto-deploys via the webhook (see deploy/README.md). This script is
# the manual path / fallback: it pushes and then fast-forwards the live
# checkout directly over SSH. Safe to run anytime — the remote pull is
# --ff-only, so it never rewrites the server's working tree.
#
#   ./scripts/deploy.sh
#
# Override the SSH host with DEPLOY_SSH_HOST=... if your ~/.ssh/config differs.
set -euo pipefail

HOST="${DEPLOY_SSH_HOST:-refuge-relay}"
SITE_DIR="/var/www/syncengine"
BRANCH="main"

echo "→ pushing $BRANCH to origin…"
git push origin "$BRANCH"

echo "→ fast-forwarding ${HOST}:${SITE_DIR}…"
ssh "$HOST" "git -C '$SITE_DIR' pull --ff-only origin '$BRANCH' && git -C '$SITE_DIR' log --oneline -1"

echo "→ verifying live site…"
curl -sI --compressed https://www.syncengine.earth/ | grep -i '^last-modified:' || true
echo "✓ done"
