# Changelog

All notable changes to this project will be documented in this file.

## [2026.6.10] - 2026-06-09

### Added
- `scripts/build-msi-installer.ps1` — WiX-based automation script to compile standalone MSI installers for the TUI apps.
- `scripts/generate-winget-manifest.ps1` — utility to generate compliant singleton YAML manifests for WinGet submission, including automated SHA256 hashing.
- `scripts/verify-icon.ps1` — scans a `dist/binaries/` folder, decodes the
  ICONDIR in every `.exe` / `.scr`, and reports PASS / FAIL per binary
  based on whether the embedded icon has all four required 32-bpp sizes
  (16/32/48/256). Companion to `library/docs/ICON_TROUBLESHOOTING.md`.
- `scripts/migrate-winres.ps1` — idempotently rewrites a `build.rs` that
  uses `winres 0.1` to use `library::build_resources` + `embed-resource`
  2.x, swaps the matching `Cargo.toml` build-dep, and re-runs
  `cargo build --release` and `verify-icon.ps1`. Safe to re-run.
  (See note below — currently blocked by an SDK bug on this host.)

### Changed
- **Descriptive Script Renaming**: Renamed core DevOps utility scripts to have descriptive, self-documenting names:
  - `build_everything.ps1` $\rightarrow$ `build-all-local.ps1` (root wrapper)
  - `git_push_all.ps1` $\rightarrow$ `tag-each-repo-with-crate-version.ps1` (root utility)
  - `scripts/build.ps1` $\rightarrow$ `scripts/compile-local-development.ps1`
  - `scripts/release.ps1` $\rightarrow$ `scripts/publish-app-release.ps1`
  - `scripts/push_all.ps1` $\rightarrow$ `scripts/push-uniform-git-tag.ps1`
- `scripts/reencode-icos.ps1` — utility that re-encodes each scene's
  multi-size ICO from PNG to BMP entries (preserved as a fallback for
  hosts where rc.exe mangles PNG-compressed 256×256 frames).
- `docs/ICON_CHECKLIST.md` — 6-item pre-ship checklist for any new
  local76 tool. Cross-linked from the library's `VISUAL_STANDARDS.md`
  and `ICON_TROUBLESHOOTING.md`.

### Known issue (unresolved, see ICON_TROUBLESHOOTING.md)
- `verify-icon.ps1` currently reports FAIL for every local76 binary
  built on Windows hosts that have the Windows SDK 10.0.26100.0
  `rc.exe`. That `rc.exe` has a confirmed ICONDIR corruption bug:
  it mangles the offset/size fields for entries 2..N of a multi-size
  ICO. Both `winres 0.1.x` and `embed-resource 2.x` wrap the same
  `rc.exe` and produce the same broken output. The screensavers
  have therefore **not** been migrated to `embed-resource` in this
  revision; the migration code in `library::build_resources` and
  `migrate-winres.ps1` is in place but inactive, ready to land
  once a toolchain workaround is found (likely: use a different
  `rc.exe`, switch to `windres`, or post-link PE rewriting).

### Changed
- `build_everything.ps1` now invokes `verify-icon.ps1` after the
  screensavers build step. The call is currently a **soft check**
  (warn-only) until the rc.exe bug is fixed upstream; once a clean
  toolchain is in place, flip it to fail-on-FAIL by removing the
  `if ($LASTEXITCODE -ne 0) { throw ... }` wrapper.

## [2026.6.9] - 2026-06-09

### Renamed
- **Project rename**: `toolkit` was previously `rTools`. The repo name, the script file names, and the docs are now lowercase `toolkit`. Behavior and scripts are unchanged.

### Changed
- README rewritten in the new register: scripts table, usage examples, layout, conventions, license.
- Added `scripts/push_all.ps1` for tag-and-push maintenance across the 9 local76 repos.
- Drop the legacy "r*" and "Local freedom" branding throughout.
- Drop `git_push_all.ps1` and `build_everything.ps1` (replaced by `push_all.ps1` and the build orchestration now lives in `scripts/build.ps1` + `scripts/release.ps1`).

## [0.1.0] - 2026-05-15

### Added
- Initial scripts: `build.ps1`, `release.ps1`.
- Empty `packaging/{deb,rpm,desktop}/` placeholders; per-app `Cargo.toml` carries the actual metadata.
