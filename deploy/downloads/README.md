# App downloads (`syncengine.earth/get/`)

The "Get the app" target for the join/donation flow — a pick-your-platform page
plus the macOS `.dmg` and Android `.apk`. The donation gateway's
`DOWNLOAD_ARTIFACT_URL` points at `https://syncengine.earth/get/`.

## Where it's served

Caddy serves `/get/*` from **`/var/www/downloads`** on refuge-relay — a
**non-git** directory, so the large binaries (~270 MB) stay out of the repo and
out of the push-to-deploy path. See the `syncengine.earth` block in
`templesofrefuge.earth/infra/Caddyfile` (`handle_path /get/*`).

Only `index.html` is tracked here (this dir); the `.dmg`/`.apk` are uploaded
separately and live only on the box.

## Publishing a new release

Artifacts come from the app repo's release pipeline
(`IndrasNetwork/agent4: scripts/release.sh` → `dist/v<ver>/`). To publish:

```bash
# from the app repo's dist/v<ver>/ (verify first)
shasum -a 256 -c SHA256SUMS.txt

# upload to the box (rsync resumes if the connection drops)
rsync -az --partial SynchronicityEngine-<ver>.dmg SynchronicityEngine-<ver>.apk \
  SHA256SUMS.txt README.txt refuge-relay:~/dl-staging/

# place + verify on the box
ssh refuge-relay '
  sudo mv ~/dl-staging/* /var/www/downloads/ && sudo rmdir ~/dl-staging
  sudo chown -R root:root /var/www/downloads
  sudo find /var/www/downloads -type f -exec chmod 644 {} \;
  cd /var/www/downloads && sha256sum -c SHA256SUMS.txt'
```

Then update `index.html` here (version string, file names, sizes, the two
SHA-256 lines) and copy it up:

```bash
scp deploy/downloads/index.html refuge-relay:/tmp/dl-index.html
ssh refuge-relay 'sudo mv /tmp/dl-index.html /var/www/downloads/index.html && sudo chmod 644 /var/www/downloads/index.html'
```

macOS `.dmg` is ad-hoc-signed (not notarized) — the page documents the one-time
right-click→Open Gatekeeper step. Notarize later if/when there's an Apple
Developer account.
