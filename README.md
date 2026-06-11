# toolkit

> Build, packaging, and release scripts for the local76 ecosystem.

No Rust code. Every binary in the local76 ecosystem is built locally
on this machine and uploaded to a GitHub Release by hand (or by the
daily scheduled task — see [Daily release automation](#daily-release-automation)
below). The toolkit is the devops layer.

---

## Scripts

### Top-level helpers (run from `toolkit/`)

| Script | What it does |
|---|---|
| `build-all-local.ps1` | One-shot build of every repo in dependency order. Equivalent to running the per-script versions in sequence. |
| `tag-each-repo-with-crate-version.ps1` | Tags every repo with its `Cargo.toml` version (idempotent; skips if tag already exists). |

### `scripts/` — the meat

#### Daily release automation

| Script | What it does |
|---|---|
| `scripts/daily-release.ps1` | The orchestrator. Runs at 04:00 PT (via Windows Task Scheduler), gates on new commits, builds everything, tags, publishes. |
| `scripts/release-check.ps1` | The gate. `git fetch` + per-repo "any new commits on `origin/main` since last tag?" check. |
| `scripts/install-daily-task.ps1` | One-time setup. Registers the Windows Task Scheduler job with `-WakeToRun` so the machine wakes from sleep at 04:00. |
| `scripts/notify-release.ps1` | Optional. Windows toast notification on success/failure. |

See [Daily release automation](#daily-release-automation) below for
the full flow.

#### Cross-platform builds (PowerShell)

| Script | What it does |
|---|---|
| `scripts/compile-local-development.ps1` | Builds every repo in dependency order: `library` → the 10 `screensaver-*` → the 5 apps. |
| `scripts/build-all-apps.ps1` | Builds just the 5 apps (`helm`, `pulse`, `scout`, `trance`, `ignite`). Useful when the library hasn't changed. |
| `scripts/build-clean-cosmos.ps1` | One-off cleaner for the `cosmos` screensaver's source after a heavy refactor. |

#### Cross-platform builds (Bash)

| Script | What it does |
|---|---|
| `scripts/build-all-screensavers.sh` | Clones all 10 `screensaver-*` repos into a local cache and runs `cargo build --release` on each. |

#### Packaging (PowerShell + Bash)

| Script | What it does |
|---|---|
| `scripts/build-all-screensaver-linux-packages.ps1` | Builds DEB packages for all 10 screensavers via the per-scene shell script below. |
| `scripts/build-screensaver-deb-packages.sh` | Builds `.deb` packages for all 10 screensavers via `cargo deb`. |

#### Release automation (PowerShell)

| Script | What it does |
|---|---|
| `scripts/publish-app-release.ps1` | Cuts a release for one app or all: compiles release binary, copies to `dist/binaries/`, tags version, pushes to GitHub, and creates a draft GitHub Release. |
| `scripts/push-uniform-git-tag.ps1` | Tags and pushes a user-specified tag across the whole ecosystem (idempotent). |

#### Migration + audit (PowerShell) — historical, mostly from the 4.0 → 4.2 era

These scripts are kept around because the audit work is repeatable
(e.g. when adding a new scene), but the migration itself is done.
They live in `scripts/archive/`.

| Script | What it does |
|---|---|
| `scripts/archive/migrate-winres.ps1` | One-time migration of a screensaver-* repo from the legacy `winres 0.1` build pipeline to the `embed-resource 2.x` + `library::core::build_resources::write_brand_rc` + `library::screensaver_runner::run_main` pipeline. |
| `scripts/archive/flatten-scenes.ps1` | Collapsed a 4-file scene subdir (`<scene>/{mod.rs, scene.rs, traits.rs, render.rs}`) into a single `<scene>.rs` per the flat layout. |
| `scripts/archive/recover-cosmos-modules.ps1` | Reassembled `cosmos.rs` from a half-broken intermediate state during the 4.0→4.2 migration. |
| `scripts/archive/verify-icon.ps1` | Reads each built `.exe` / `.scr` and verifies the ICONDIR has 4 valid 32-bpp sub-icons (16, 32, 48, 256). See `library/docs/ICON_TROUBLESHOOTING.md`. |
| (and 14 more historical scripts) | See `scripts/archive/`. |

---

## Daily release automation

A Windows Task Scheduler job runs `scripts/daily-release.ps1` every
day at 04:00 PT. The job:

1. **Gates on new commits**. `release-check.ps1` does
   `git fetch origin` in every repo, then asks: for each repo, is
   `origin/main` ahead of the most recent `v<date>` tag? If all repos
   are at their latest tag, the script logs "no release needed" and
   exits 0. If any repo has new commits, the full release cycle runs.
2. **Builds**. Compiles `library` (release profile), then each
   `screensaver-*` (producing `.exe` and `.scr`), then each app
   (producing `.exe`). Linux `.deb` packages are built via WSL2 if
   available; otherwise the script logs a warning and ships
   `.exe`/`.scr` only.
3. **Tags**. `tag-each-repo-with-crate-version.ps1` writes a
   `v<date>` tag to every repo. `push-uniform-git-tag.ps1` pushes
   the tag to origin.
4. **Publishes**. `gh release create v<date>` uploads the assets
   (the `.exe`, `.scr`, and `.deb` files) to a draft GitHub Release
   on each repo.
5. **Logs**. A daily log is written to
   `dist/logs/daily-release-<YYYY-MM-DD>.log`.
6. **Notifies** (optional). `notify-release.ps1` shows a Windows
   toast on success/failure.

### One-time setup

```powershell
# 1. WSL2 with Ubuntu + Rust + cargo-deb (only needed for .deb)
wsl --install -d Ubuntu
# in WSL:
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install cargo-deb

# 2. Verify gh is authed
gh auth status

# 3. Register the scheduled task (one-time)
pwsh ./toolkit/scripts/install-daily-task.ps1
```

After setup, the daily task runs unattended. The user only has to
`git push` their work to GitHub when they're done for the day; the
build + tag + release happens overnight.

### What you need to do

**Nothing.** That's the point. Push your commits when you're done
with work, and the 04:00 PT task handles the rest. The machine
needs to be on (or have `-WakeToRun` enabled) at 04:00.

If the machine is off at 04:00, the task runs at next boot
(`-StartWhenAvailable`).

### What the script does NOT do

- **No GitHub Actions.** The task runs on your local machine, not
  on GitHub's runners.
- **No CI cache.** `cargo build --release` is fast enough (1-2 min
  per crate × 16 crates = 30-40 min) that no cache is needed.
- **No CI tokens.** The `gh` CLI uses your personal auth token.
- **No cloud, no telemetry.** Everything happens on your box.

---

## Usage

From the monorepo root (`C:\Users\jeryd\Synology\Home\Projects\local76`
on Windows, `~/Synology/Home/Projects/local76` on Linux):

```pwsh
# Build everything locally
pwsh ./toolkit/scripts/compile-local-development.ps1

# Build just the 5 apps
pwsh ./toolkit/scripts/build-all-apps.ps1

# Build a single app locally
pwsh ./toolkit/scripts/compile-local-development.ps1 -SkipLibrary -SkipScreensavers -App helm

# Build DEB packages for all screensavers (Linux)
pwsh ./toolkit/scripts/build-all-screensaver-linux-packages.ps1

# Cut a release for one app
pwsh ./toolkit/scripts/publish-app-release.ps1 -App helm -Version 2026.6.10.1

# Verify cargo dep pins (tag, not branch)
pwsh ./toolkit/scripts/verify-pins.ps1
```

Or use the unified entry point at the monorepo root:

```pwsh
pwsh ./run.ps1 build
pwsh ./run.ps1 test
pwsh ./run.ps1 deb
pwsh ./run.ps1 release helm 2026.6.10.1
pwsh ./run.ps1 verify
```

---

## Layout

```
toolkit/
├── README.md
├── LICENSE.md
├── build-all-local.ps1                       # Root quick-build helper
├── tag-each-repo-with-crate-version.ps1      # Root version tag helper
└── scripts/
    ├── daily-release.ps1                     # Daily 04:00 PT orchestrator
    ├── release-check.ps1                     # "Any new commits?" gate
    ├── install-daily-task.ps1                # One-time Windows Task Scheduler setup
    ├── notify-release.ps1                    # Optional Windows toast
    ├── verify-pins.ps1                       # Asserts every Cargo.toml uses tag, not branch
    ├── compile-local-development.ps1
    ├── build-all-apps.ps1
    ├── build-clean-cosmos.ps1
    ├── build-all-screensaver-linux-packages.ps1
    ├── build-all-screensavers.sh
    ├── build-screensaver-deb-packages.sh
    ├── publish-app-release.ps1
    ├── push-uniform-git-tag.ps1
    └── archive/                              # Historical migration/audit scripts
```

DEB packaging is done via `cargo deb` reading
`[package.metadata.deb]` from each `screensaver-*` `Cargo.toml`. The
`.desktop` entries live in each app's `assets/` directory.

---

## Adding a new app to the ecosystem

1. Create a new repo at `https://github.com/local76/<name>`.
2. Add the repo as a sibling of `toolkit/` in the monorepo
   (`~/Synology/Home/Projects/local76/<name>`).
3. The new repo's `Cargo.toml` must depend on `library` via the git
   tag pin (`tag = "v<version>"`) for release, or `path = "../library"`
   for local dev. The `[patch]` block is added automatically.
4. Add the new repo's build step to
   `scripts/compile-local-development.ps1` and
   `scripts/build-all-apps.ps1` (the latter if it's an app).
5. Bump the ecosystem version (CalVer) in all `Cargo.toml` files
   and push. The daily task picks it up.

---

## License

MIT. See [LICENSE.md](LICENSE.md).
