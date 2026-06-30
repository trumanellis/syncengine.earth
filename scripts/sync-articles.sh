#!/bin/bash
# sync-articles.sh — mirror the Indra's Network article markdown on-domain
#
# The articles' canonical home is the trumanellis/IndrasNetwork repo;
# articles/read.html historically fetched them from raw.githubusercontent.com
# at view time. raw.githubusercontent.com forbids crawlers via robots.txt,
# so AI agents and search engines could never read the article text. This
# script vendors a copy of each article at ./articles/<slug>.md so the text
# is served from syncengine.earth itself (and read.html loads the local copy
# first).
#
# The slug list is read from articles/articles.json — add an article there
# and re-run:
#
#   ./scripts/sync-articles.sh
#
# By default it copies from the sibling working tree at ../IndrasNetwork
# when present, otherwise it fetches via the authenticated GitHub API
# (the IndrasNetwork repo is private, so anonymous raw URLs 404 — which
# also means read.html's old runtime fetch never worked for visitors).
# Override with ARTICLES_SRC to pull from a different local checkout or
# base URL.

set -euo pipefail

# Resolve repo root regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_LOCAL_SRC="$REPO_ROOT/../IndrasNetwork/articles"

if [[ -n "${ARTICLES_SRC:-}" ]]; then
  SRC="$ARTICLES_SRC"
elif [[ -d "$DEFAULT_LOCAL_SRC" ]]; then
  SRC="$DEFAULT_LOCAL_SRC"
else
  SRC="gh-api"
fi

DST="$REPO_ROOT/articles"

SLUGS=$(python3 -c "
import json
for a in json.load(open('$REPO_ROOT/articles/articles.json')):
    print(a['slug'])
")

echo "Source: $SRC"
for slug in $SLUGS; do
  if [[ "$SRC" == "gh-api" ]]; then
    echo "  fetching $slug.md (gh api) ..."
    gh api -H "Accept: application/vnd.github.raw" \
      "repos/trumanellis/IndrasNetwork/contents/articles/$slug.md" > "$DST/$slug.md"
  elif [[ "$SRC" =~ ^https?:// ]]; then
    echo "  fetching $slug.md ..."
    curl --fail --silent --show-error --output "$DST/$slug.md" "$SRC/$slug.md"
  elif [[ -f "$SRC/$slug.md" ]]; then
    echo "  copying $slug.md ..."
    cp "$SRC/$slug.md" "$DST/$slug.md"
  else
    echo "ERROR: $SRC/$slug.md not found" >&2
    exit 1
  fi
done

# Diff against last commit so the operator sees what changed.
if [[ -z "$(git -C "$REPO_ROOT" status --porcelain -- 'articles/*.md')" ]]; then
  echo "No changes — vendored copies already match upstream."
else
  echo ""
  echo "Vendored articles updated. Review the diff and commit:"
  echo "  git -C $REPO_ROOT diff articles/"
  echo ""
  echo "Then regenerate the agent assets:"
  echo "  ./scripts/build-agent-assets.sh"
fi
