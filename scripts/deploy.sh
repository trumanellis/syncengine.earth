#!/usr/bin/env bash
# deploy.sh — publish syncengine.earth.
#
# The live site is served by Caddy from a git checkout on the relay box
# (refuge-relay:/var/www/syncengine); GitHub is only the origin. A push
# normally auto-deploys via the webhook (see deploy/README.md), which runs its
# own `git pull` in that same checkout — so this script pushes, waits for the
# webhook to land, and only fast-forwards the checkout itself if the webhook
# never showed up. Racing it is what used to fail the deploy: our fetch moved
# refs/heads/main out from under the webhook's in-flight checkout, and git
# aborted with "Cannot fast-forward your working tree".
#
# Safe to run anytime, and safe to re-run: the fallback is an --ff-only merge
# of an exact commit, so it never rewrites the server's working tree and is a
# no-op once the site is current.
#
#   ./scripts/deploy.sh
#
# Override the SSH host with DEPLOY_SSH_HOST=... if your ~/.ssh/config differs,
# or the webhook grace period with DEPLOY_WEBHOOK_WAIT=<seconds> (0 skips the
# wait and goes straight to the manual fast-forward).
set -euo pipefail

HOST="${DEPLOY_SSH_HOST:-refuge-relay}"
SITE_DIR="/var/www/syncengine"
BRANCH="main"
WEBHOOK_WAIT="${DEPLOY_WEBHOOK_WAIT:-45}"

# HEAD of the live checkout; empty if it can't be read (SSH down, mid-write).
remote_head() {
  ssh "$HOST" "git -C '$SITE_DIR' rev-parse HEAD" 2>/dev/null | tr -d '[:space:]'
}

# Read the live HEAD before pushing, so the report afterwards can tell "the
# site was already current" apart from "the webhook deployed it" — the webhook
# often wins before our first poll even gets a reply.
before="$(remote_head)"

echo "→ pushing $BRANCH to origin…"
git push origin "$BRANCH"
TARGET="$(git rev-parse "$BRANCH")"
SHORT="${TARGET:0:8}"

echo "→ waiting up to ${WEBHOOK_WAIT}s for the webhook to deploy ${SHORT}…"
head=""
deadline=$(( SECONDS + WEBHOOK_WAIT ))
while :; do
  head="$(remote_head)"
  [ "$head" = "$TARGET" ] && break
  [ "$SECONDS" -ge "$deadline" ] && break
  sleep 2
done

if [ "$head" = "$TARGET" ]; then
  if [ "$before" = "$TARGET" ]; then
    echo "  nothing to deploy, live checkout already at ${SHORT}."
  else
    echo "  webhook deployed it."
  fi
else
  echo "→ webhook didn't land it (live HEAD ${head:-unknown}); fast-forwarding over SSH…"
  # Fetch the explicit refspec into the remote-tracking ref only. A bare
  # `git fetch origin main` can update refs/heads/main directly (depending on
  # the checkout's configured refspec) and drag the working tree with it —
  # exactly the behaviour that collides with a concurrent webhook pull.
  # Merging a named commit --ff-only keeps the tree update ours to control,
  # and exits 0 ("Already up to date") if the webhook lands mid-flight.
  if ! out="$(ssh "$HOST" "
        set -e
        git -C '$SITE_DIR' fetch --quiet origin '+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH'
        git -C '$SITE_DIR' merge --ff-only '$TARGET'
      " 2>&1)"; then
    # Don't fail yet: a webhook pull finishing during our merge can make it
    # exit non-zero while still leaving the site on the right commit.
    echo "$out" | sed 's/^/  /'
  fi
  head="$(remote_head)"
fi

if [ "$head" != "$TARGET" ]; then
  echo "✗ live checkout is at ${head:-unknown}, expected $TARGET" >&2
  echo "  logs:  ssh $HOST 'journalctl -u webhook-deploy -n 50'" >&2
  exit 1
fi

# HEAD alone isn't proof the files on disk are right — an interrupted pull can
# move the ref and leave the working tree behind. A clean tree is the proof.
dirty="$(ssh "$HOST" "git -C '$SITE_DIR' status --porcelain --untracked-files=no")"
if [ -n "$dirty" ]; then
  echo "✗ live working tree doesn't match HEAD $SHORT:" >&2
  echo "$dirty" | sed 's/^/  /' >&2
  echo "  inspect:  ssh $HOST \"git -C $SITE_DIR diff\"" >&2
  echo "  recover:  ssh $HOST \"git -C $SITE_DIR checkout -- .\"" >&2
  exit 1
fi

echo "→ verifying live site…"
ssh "$HOST" "git -C '$SITE_DIR' log --oneline -1" | sed 's/^/  /'
curl -sI --compressed https://www.syncengine.earth/ | grep -i '^last-modified:' || true
echo "✓ done"
