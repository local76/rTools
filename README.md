# rTools — local76 CLI dev tools

`rTools` is the umbrella org for the CLI / shell / build-orchestration
tooling that keeps the local76 r* ecosystem building and shipping in
lockstep. There is no Rust code in this repo — it's a pure-DevOps
collection of PowerShell + bash scripts that the maintainers run from
the `local76/` workspace root.

## Scripts

| Script | Platform | Purpose | Status |
|---|---|---|---|
| `build_everything.ps1` | Windows | Top-level orchestrator. Builds `rCommon` (debug + release), all 6 r* TUI apps (release), and the 10 r* scene shim binaries (release) in the right dependency order. Auto-detects each app's local `build_all.ps1` (or falls back to plain `cargo build --release`). Parameters: `-SkipCommon`, `-SkipApps`, `-SkipScenes`, `-Release` (default true). | ✅ shipped |
| `git_push_all.ps1` | Windows | Tag + push helper. Reads each repo's current version from `Cargo.toml` (or the most recent `v*` annotated tag as a fallback for the rApps/rTools umbrellas that have no Cargo.toml), creates an annotated `v<version>` tag, and `git push origin main --follow-tags`. Idempotent — safe to re-run. | ✅ shipped |
| `setup_dev_env.ps1` | (planned) | One-shot dev environment bootstrap: install Rust + cargo-deb + cargo-generate-rpm + winres + ripgrep. Windows-side analog of the `setup_linux_dev.sh` script. | 🚧 planned |
| `setup_linux_dev.sh` | (planned) | Linux dev environment bootstrap: `apt install cargo rustc musl-tools` + `cargo install cargo-deb cargo-generate-rpm`. Counterpart to `setup_dev_env.ps1`. | 🚧 planned |
| `release_orchestrator.py` | (planned) | Cross-platform release script: bumps versions across all 8 Rust repos in lockstep, generates the consolidated CHANGELOG, creates GitHub Releases with the build artifacts attached. | 🚧 planned |

## Install-path convention (Windows + Linux)

The local76 r* ecosystem uses two install-path buckets:

| Bucket | Path | Purpose |
|---|---|---|
| TUI apps | `usr/bin/<app>` | The 6 r* TUI apps (rFetch, rIdle, rMonitor, rStartup, rTemplate, rWifi). Each gets its own binary in `usr/bin/`. |
| Screensaver shims | `usr/libexec/r-screensaver-shims/<Name>` | The 10 r* screensaver effects (rMatrix, rBeams, rBhop, rFire, rFireflies, rFireworks, rLife, rParty, rPour, rUnstable). All 10 share `r-screensaver-shims/` as a single dir; rIdle (the screensaver picker) scans this dir. |

The shim path was renamed from `r-idle-scenes/` to `r-screensaver-shims/` in rScenes 4.1.0 to match the post-4.0 rScenes rename; the deb/rpm package names were renamed from `r-idle-scene-*` to `r-scene-*` at the same time.

The per-app config + log storage convention is documented in the [rApps README](https://github.com/local76/rApps#per-app-config--log-storage).

## How to use

These scripts assume the standard local76 sibling layout:
```
local76/
├── README.md                  (this org's overview)
├── SYSTEM-SETUP.md            (one-time dev env setup)
├── build_everything.ps1       (← from rTools)
├── git_push_all.ps1           (← from rTools)
├── rApps/                     (the 6 TUI apps — sub-repos)
│   ├── rFetch/
│   ├── rIdle/
│   ├── rMonitor/
│   ├── rStartup/
│   ├── rTemplate/
│   └── rWifi/
├── rCommon/                   (the shared design system + 10 screensaver effects)
└── rScenes/                   (the 10 standalone screensaver binaries)
```

The scripts `cd` into each sibling repo as needed. They never move
files between repos — each repo is independent and self-contained.

## What's NOT here (on purpose)

- **No Rust code** — rTools is pure DevOps. Rust code goes in rCommon, rFetch, etc.
- **No build artifacts** — `target/` is gitignored everywhere; release binaries are uploaded as GitHub Release assets by the CI workflows in each r* repo.
- **No secrets** — there are no API keys, no signing certs, no CI tokens stored in this repo. All CI uses GitHub's built-in `GITHUB_TOKEN`.

## Adding a new script

1. Add the `.ps1` (Windows) or `.sh` (Linux) file to this repo.
2. If it's a cross-platform workflow, prefer bash (POSIX) and document
   the `bash <(curl ...)` invocation in the script's `## Usage` comment.
3. Update the table above.
4. If the script needs to be invoked from a specific cwd, document that
   in a comment block at the top of the file (e.g. `# Run from the local76/ root`).

## License

MIT.
