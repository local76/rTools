# toolkit

> Build, packaging, and release scripts for the local76 ecosystem.

No Rust code. No GitHub Actions. No CI. Every binary in the local76 ecosystem is built locally on this machine and uploaded to a GitHub Release by hand. The toolkit is the devops layer.

---

## Scripts

| Script | What it does |
|---|---|
| `scripts/compile-local-development.ps1` | Builds every repo in dependency order: `library` → `screensavers` → the 5 apps. |
| `scripts/publish-app-release.ps1` | Cuts a release for one app or all: compiles release binary, copies to `dist/binaries/`, tags version, pushes to GitHub, and creates a draft GitHub Release. |
| `scripts/push-uniform-git-tag.ps1` | Tags and pushes a user-specified tag across the whole ecosystem (idempotent). |
| `scripts/build-msi-installer.ps1` | Compiles a Windows MSI installer for the app using cargo-wix and WiX Toolset. |
| `scripts/generate-winget-manifest.ps1` | Generates a singleton YAML manifest for submitting the app to the Windows Package Manager (WinGet). |

---

## Usage

From the monorepo root (`C:\Users\jeryd\Synology\Home\Projects\local76` on Windows, `~/Synology/Home/Projects/local76` on Linux):

```pwsh
# Build everything locally
pwsh ./toolkit/scripts/compile-local-development.ps1

# Build a single app locally
pwsh ./toolkit/scripts/compile-local-development.ps1 -SkipLibrary -SkipScreensavers -App helm

# Package Windows MSI installer
pwsh ./toolkit/scripts/build-msi-installer.ps1 -App helm -Version 2026.6.9

# Generate WinGet manifest for MSI
pwsh ./toolkit/scripts/generate-winget-manifest.ps1 -App helm -Version 2026.6.9 -MsiPath ./helm/dist/binaries/helm_v2026.6.9_x64.msi

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
├── scripts/
│   ├── compile-local-development.ps1
│   ├── publish-app-release.ps1
│   ├── push-uniform-git-tag.ps1
│   ├── build-msi-installer.ps1
│   └── generate-winget-manifest.ps1
└── packaging/
    ├── msi/            # WiX configuration templates
    ├── winget/         # Generated WinGet YAML manifests
    ├── deb/            # Empty (cargo deb reads metadata from Cargo.toml)
    ├── rpm/            # Empty (cargo generate-rpm reads metadata from Cargo.toml)
    └── desktop/        # Empty (desktop templates are in each app repo)
```

`packaging/` is intentionally empty. Each app's `Cargo.toml` carries the `[package.metadata.deb]` and `[package.metadata.generate-rpm]` metadata; `cargo deb` and `cargo generate-rpm` read it directly. The `.desktop` entries live in each app's `assets/` directory.

---

## Conventions

- **No GitHub Actions.** All builds are local. All releases are cut by hand.
- **No bash.** PowerShell Core (`pwsh`) is the only shell dependency. Runs on Windows and Linux.
- **No CI tokens.** The `gh` CLI uses your personal auth token.
- **No CI cache.** `cargo build --release` is fast enough (1-2 min per app) that no cache is needed.

---

## Adding a new app to the ecosystem

1. Create a new repo at `https://github.com/local76/<name>`.
2. Add the repo as a sibling of `toolkit/` in the monorepo (`~/Synology/Home/Projects/local76/<name>`).
3. The new repo's `Cargo.toml` must depend on `library` via the `[patch]` redirect.
4. Add the new repo's build step to `scripts/build.ps1`.
5. Add the new repo to the apps list in `scripts/push_all.ps1`.
6. Bump `toolkit` to `v0.2.0` and push.

---

## License

MIT. See [LICENSE.md](LICENSE.md).
