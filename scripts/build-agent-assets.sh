#!/bin/bash
# build-agent-assets.sh — regenerate llms-full.txt and sitemap.xml
#
# llms.txt is hand-authored (it is the project's voice toward agents — edit
# it directly). This script derives the two mechanical assets from it:
#
#   llms-full.txt  = llms.txt + full whitepaper + full Covenant + all article
#                    markdown, concatenated for agents that prefer one fetch
#   sitemap.xml    = the HTML pages + article reader URLs + markdown sources
#                    + the llms files, with lastmod from git
#
# Run after ./scripts/sync-articles.sh, after editing the whitepaper or
# Covenant, or after editing llms.txt:
#
#   ./scripts/build-agent-assets.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"
python3 - <<'PY'
import json
import subprocess
from datetime import date

BASE = "https://www.syncengine.earth"

articles = json.load(open("articles/articles.json"))

# ── llms-full.txt ────────────────────────────────────────────────────────
divider = "\n\n" + "=" * 72 + "\n"

def section(title, path):
    body = open(path).read().strip()
    return f"{divider}# SOURCE: {title}\n# {BASE}/{path}\n{'=' * 72}\n\n{body}"

parts = [open("llms.txt").read().strip()]
parts.append(section("The Conservation of Attention (whitepaper)",
                     "articles/WhitePaper.md"))
parts.append(section("The Indra's Network Membership Covenant",
                     "COVENANT.md"))
for a in articles:
    parts.append(section(f"Article: {a['title']} — {a['subtitle']}",
                         f"articles/{a['slug']}.md"))

with open("llms-full.txt", "w") as f:
    f.write("\n".join(parts) + "\n")

# ── sitemap.xml ──────────────────────────────────────────────────────────
def lastmod(path):
    """Last git commit date for path; falls back to today for new files."""
    out = subprocess.run(
        ["git", "log", "-1", "--format=%cs", "--", path],
        capture_output=True, text=True).stdout.strip()
    return out or date.today().isoformat()

urls = [
    ("index.html", BASE + "/"),
    ("gift-cycle.html", None),
    ("network.html", None),
    ("agents.html", None),
    ("join.html", None),
    ("whitepaper.html", None),
    ("community.html", None),
    ("covenant.html", None),
    ("articles/index.html", BASE + "/articles/"),
    ("articles/WhitePaper.md", None),
    ("COVENANT.md", None),
    ("llms.txt", None),
    ("llms-full.txt", None),
]
for a in articles:
    slug = a["slug"]
    urls.append((f"articles/{slug}.md",
                 f"{BASE}/articles/read.html?slug={slug}"))
    urls.append((f"articles/{slug}.md", None))

lines = ['<?xml version="1.0" encoding="UTF-8"?>',
         '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
for path, loc in urls:
    loc = loc or f"{BASE}/{path}"
    loc = loc.replace("&", "&amp;")
    lines.append(f"  <url><loc>{loc}</loc><lastmod>{lastmod(path)}</lastmod></url>")
lines.append("</urlset>")

with open("sitemap.xml", "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"llms-full.txt: {len(open('llms-full.txt').read()):,} chars")
print(f"sitemap.xml:   {len(urls)} URLs")
PY
