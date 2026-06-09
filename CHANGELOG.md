# Changelog

All notable changes to this project will be documented in this file.

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
