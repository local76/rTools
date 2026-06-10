# toolkit

> Build, packaging, and release scripts for the local76 ecosystem.

No Rust code. No GitHub Actions. No CI. Every binary in the local76 ecosystem is built locally on this machine and uploaded to a GitHub Release by hand. The toolkit is the devops layer.

---

## Scripts

### Top-level helpers (run from `toolkit/`)

| Script | What it does |
|---|---|
| `build-all-local.ps1` | One-shot build of every repo in dependency order. Equivalent to running the per-script versions in sequence. |
| `tag-each-repo-with-crate-version.ps1` | Tags every repo with its `Cargo.toml` version (idempotent; skips if tag already exists). |

### `scripts/` — the meat

#### Cross-platform builds (PowerShell)

| Script | What it does |
|---|---|
| `scripts/compile-local-development.ps1` | Builds every repo in dependency order: `library` → the 10 `screensavers-*` → the 5 TUI apps. |
| `scripts/build-all-apps.ps1` | Builds just the 5 TUI apps (`helm`, `pulse`, `scout`, `trance`, `ignite`). Useful when the library hasn't changed. |
| `scripts/build-clean-cosmos.ps1` | One-off cleaner for the `cosmos` screensaver's source after a heavy refactor. |

#### Cross-platform builds (Bash)

| Script | What it does |
|---|---|
| `scripts/build-all-screensavers.sh` | Clones all 10 `screensavers-*` repos into a local cache and runs `cargo build --release` on each. |

#### Packaging (PowerShell + Bash)

| Script | What it does |
|---|---|
| `scripts/build-all-screensavers-linux-packages.ps1` | Builds DEB packages for all 10 screensavers via the per-scene shell script below. |
| `scripts/build-screensavers-deb-packages.sh` | Builds `.deb` packages for all 10 screensavers via `cargo deb`. |

#### Release automation (PowerShell)

| Script | What it does |
|---|---|
| `scripts/publish-app-release.ps1` | Cuts a release for one app or all: compiles release binary, copies to `dist/binaries/`, tags version, pushes to GitHub, and creates a draft GitHub Release. |
| `scripts/push-uniform-git-tag.ps1` | Tags and pushes a user-specified tag across the whole ecosystem (idempotent). |

#### Migration + audit (PowerShell) — historical, mostly 4.0→4.2

These scripts were used to do the 4.0→4.2 migration of the screensavers (split into 10 repos, embed-resource 2.x pipeline, `screensaver_shim!` macro). They are kept around because the audit work is repeatable (e.g. when adding a new scene), but the migration itself is done.

| Script | What it does |
|---|---|
| `scripts/migrate-winres.ps1` | One-time migration of a screensavers-* repo from the legacy `winres 0.1` build pipeline to the 4.2 `embed-resource 2.x` + `library::core::build_resources::write_brand_rc` + `library::screensaver_shim!` pipeline. |
| `scripts/flatten-scenes.ps1` | Collapsed a 4-file scene subdir (`<scene>/{mod.rs, scene.rs, traits.rs, render.rs}`) into a single `<scene>.rs` per the 4.2 layout. |
| `scripts/flatten-complex-scenes.ps1` | Same as above, for the heavy `bounce.rs` and `cosmos.rs` scenes. |
| `scripts/flatten-complex-proper.ps1` | Cleanup pass after `flatten-complex-scenes.ps1` to fix use-statement grouping. |
| `scripts/merge-use-statements.ps1` | Merges adjacent `use` statements from the same crate root into a single `use {a, b, c};`. |
| `scripts/dedup-use-statements.ps1` | Removes duplicate `use crate::...` lines. |
| `scripts/drop-redundant-self-uses.ps1` | Removes `use crate::self_mod;` when the module's items are referenced as `Self::X`. |
| `scripts/clean-complex-scene-imports.ps1` | Cleans up the import block in `bounce.rs` and `cosmos.rs` after the flatten. |
| `scripts/clean-complex-scene-imports-v2.ps1` | v2 of the above (for scenes that needed a second pass). |
| `scripts/fix-brace-mismatch.ps1` | Fixes mismatched `{`/`}` in scenes that had a hand-rolled `unsafe` block. |
| `scripts/fix-complex-references.ps1` | Fixes `crate::foo::bar` paths that broke when scenes were moved into the 4.2 flat `screensavers/` tree. |
| `scripts/fix-scene-refs.ps1` | Same as above, broader sweep. |
| `scripts/fix-head-issues.ps1` | One-off fix for a set of `cosmic_ray`-style header ordering issues in scenes. |
| `scripts/fix-cosmos-state.ps1` | One-off fix for `cosmos.rs` when the Screensaver trait was rewritten. |
| `scripts/recover-cosmos-modules.ps1` | Reassembled `cosmos.rs` from a half-broken intermediate state during the 4.0→4.2 migration. |
| `scripts/reencode-icos.ps1` | Re-encoded source `.ico` files using `magick convert` to fix the `rc.exe 10.0+` ICONDIR-corruption bug. The `library::core::rc_split::split_for_rc` workaround is the long-term fix; this script is the one-time bulk repair for the historical asset folder. |
| `scripts/verify-icon.ps1` | Reads each built `.exe` / `.scr` and verifies the ICONDIR has 4 valid 32-bpp sub-icons (16, 32, 48, 256). See `library/docs/ICON_TROUBLESHOOTING.md`. |

---

## Usage

From the monorepo root (`C:\Users\jeryd\Synology\Home\Projects\local76` on Windows, `~/Synology/Home/Projects/local76` on Linux):

```pwsh
# Build everything locally
pwsh ./toolkit/scripts/compile-local-development.ps1

# Build just the 5 TUI apps
pwsh ./toolkit/scripts/build-all-apps.ps1

# Build a single app locally
pwsh ./toolkit/scripts/compile-local-development.ps1 -SkipLibrary -SkipScreensavers -App helm

# Build DEB packages for all screensavers (Linux)
pwsh ./toolkit/scripts/build-all-screensavers-linux-packages.ps1

# Cut a release
pwsh ./toolkit/scripts/publish-app-release.ps1 -App helm -Version 2026.6.9
```

---

## Layout

```
toolkit/
├── README.md
├── LICENSE.md
├── build-all-local.ps1                       # Root quick-build helper
├── tag-each-repo-with-crate-version.ps1      # Root version tag helper
└── scripts/                                  # See Scripts table above
    ├── compile-local-development.ps1
    ├── build-all-apps.ps1
    ├── build-clean-cosmos.ps1
    ├── build-all-screensavers-linux-packages.ps1
    ├── build-all-screensavers.sh
    ├── build-screensavers-deb-packages.sh
    ├── publish-app-release.ps1
    ├── push-uniform-git-tag.ps1
    └── archive/                              # 18 historical migration/audit scripts
```

DEB packaging is done via `cargo deb` reading `[package.metadata.deb]` from each `screensavers-*` `Cargo.toml`. The `.desktop` entries live in each app's `assets/` directory.

---

## Conventions

- **No GitHub Actions.** All builds are local. All releases are cut by hand.
- **No bash where avoidable.** PowerShell Core (`pwsh`) is the default shell. The `*.sh` files are only for Linux packaging (where `cargo deb` and `cargo generate-rpm` are native).
- **No CI tokens.** The `gh` CLI uses your personal auth token.
- **No CI cache.** `cargo build --release` is fast enough (1-2 min per app) that no cache is needed.
- **One file per script.** Each script does one thing. Compose at the shell level.

---

## Adding a new app to the ecosystem

1. Create a new repo at `https://github.com/local76/<name>`.
2. Add the repo as a sibling of `toolkit/` in the monorepo (`~/Synology/Home/Projects/local76/<name>`).
3. The new repo's `Cargo.toml` must depend on `library` via the git branch pin (`branch = "main"`).
4. Add the new repo's build step to `scripts/compile-local-development.ps1` and `scripts/build-all-apps.ps1` (the latter if it's a TUI app).
5. Bump `toolkit` to the next version and push.

---

## License

MIT. See [LICENSE.md](LICENSE.md).
