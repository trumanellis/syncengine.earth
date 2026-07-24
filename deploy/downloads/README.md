# App downloads (`syncengine.earth/get/`)

The "Get the app" target for the join/donation flow — a pick-your-platform page
that links straight to the current release binaries. The donation gateway's
`DOWNLOAD_ARTIFACT_URL` points at `https://syncengine.earth/get/`.

## Where the binaries live now

**GitHub Releases**, on a small **public** repo:
[`trumanellis/syncengine-releases`](https://github.com/trumanellis/syncengine-releases/releases).
The app source (`trumanellis/IndrasNetwork`) stays private; only the built
`.dmg`/`.apk` are published to the public repo, so the website can link them
without auth. The download buttons here point at the **stable latest-release
permalinks**, which always resolve to the newest release's asset:

```
https://github.com/trumanellis/syncengine-releases/releases/latest/download/SyncEngine-macos.dmg
https://github.com/trumanellis/syncengine-releases/releases/latest/download/SyncEngine-android.apk
```

Because the asset names are versionless and `…/latest/download/…` follows the
newest release, **this page never needs editing per release** — no version
string, no file sizes, no SHA lines to update by hand. (Contrast the old flow:
rsync ~270 MB to refuge-relay's non-git `/var/www/downloads`, then hand-edit
this HTML and scp it up. Retired.)

## Publishing a new release

Fully automated from the app repo — no manual upload:

1. In `IndrasNetwork`, bump `[workspace.package] version` in `Cargo.toml` if needed.
2. Tag and push: `git tag v1.0.2 && git push origin v1.0.2`.
3. The `Release` GitHub Actions workflow builds the macOS `.dmg` + Android `.apk`,
   renames them to the stable names, and publishes a GitHub Release (with
   `SHA256SUMS.txt`) to `syncengine-releases`. This page picks it up
   automatically.

One-time setup the workflow depends on:
- **`ANDROID_KEYSTORE_B64`** secret (base64 of the release keystore).
- **`RELEASES_REPO_TOKEN`** secret — a PAT / fine-grained token with
  `contents:write` on `syncengine-releases`.
- The `syncengine-releases` public repo must exist (needs one commit so tags
  can be created against its default branch).

## Notes

- macOS `.dmg` is ad-hoc-signed (not notarized) — the page documents the one-time
  "Open Anyway" Gatekeeper step. Notarize later if/when there's an Apple
  Developer account.
- **Intel Mac** and **Linux/Windows/iOS** are not yet in the pipeline (Phase 1 =
  Apple Silicon + Android). The page says "Intel build coming soon"; add the
  button back when the workflow's Intel/Linux legs land and start emitting
  `SyncEngine-macos-intel.dmg` etc.
- The Caddy `handle_path /get/*` block that served the old box-hosted binaries
  can be simplified/retired now that nothing large is served from the box — the
  only file left is this `index.html`.
