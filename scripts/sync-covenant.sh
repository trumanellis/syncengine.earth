#!/bin/bash
# sync-covenant.sh — re-mirror the canonical Covenant from templesofrefuge.earth
#
# The Covenant's canonical home is the templesofrefuge.earth repo
# (the website of the church that stewards the Synchronicity Engine).
# This site keeps a vendored copy at ./COVENANT.md so /covenant.html
# can render it instantly without depending on a cross-origin fetch.
#
# Run this script whenever the upstream covenant changes:
#
#   ./scripts/sync-covenant.sh
#
# By default it copies from the sibling working tree at
# ../templesofrefuge.earth. Override with COVENANT_SRC to pull from
# elsewhere (e.g. a GitHub raw URL or a different local checkout).

set -euo pipefail

# Resolve repo root regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default source: the sibling working tree.
DEFAULT_SRC="$REPO_ROOT/../templesofrefuge.earth/COVENANT.md"
SRC="${COVENANT_SRC:-$DEFAULT_SRC}"
DST="$REPO_ROOT/COVENANT.md"

if [[ "$SRC" =~ ^https?:// ]]; then
  echo "Fetching from $SRC ..."
  curl --fail --silent --show-error --output "$DST" "$SRC"
elif [[ -f "$SRC" ]]; then
  echo "Copying from $SRC ..."
  cp "$SRC" "$DST"
else
  echo "ERROR: source not found at $SRC" >&2
  echo "" >&2
  echo "Set COVENANT_SRC to a local path or URL, e.g.:" >&2
  echo "  COVENANT_SRC=https://raw.githubusercontent.com/trumanellis/templesofrefuge.earth/main/COVENANT.md \\" >&2
  echo "    ./scripts/sync-covenant.sh" >&2
  exit 1
fi

# Diff against last commit so the operator sees what changed.
if git -C "$REPO_ROOT" diff --quiet -- "$DST"; then
  echo "No changes — vendored copy already matches upstream."
else
  echo ""
  echo "Vendored Covenant updated. Review the diff and commit:"
  echo "  git -C $REPO_ROOT diff COVENANT.md"
fi
