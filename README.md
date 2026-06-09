# toolkit

> Build, packaging, and release scripts for the local76 ecosystem.

No Rust code. No GitHub Actions. No CI. Every binary in the local76 ecosystem is built locally on this machine and uploaded to a GitHub Release by hand. The toolkit is the devops layer.

---

## Scripts

| Script | What it does |
|---|---|
| `scripts/build.ps1` | Builds every repo in dependency order: `library` → `screensavers` → the 5 apps. Supports `-SkipLibrary`, `-SkipScreensavers`, `-SkipApps`, `-Release`, `-App <name>`. |
| `scripts/release.ps1` | Cuts a release for one app or all (`-All`): builds release, copies to `dist/binaries/`, commits, tags `v$Version`, pushes, creates a draft GitHub Release with all artifacts attached. |
| `scripts/push_all.ps1` | Tags + pushes a release tag across the whole ecosystem. Idempotent: skips repos that already have the tag. |

---

## Usage

From the monorepo root (`C:\Users\jeryd\Synology\Home\Projects\local76` on Windows, `~/Synology/Home/Projects/local76` on Linux):

```pwsh
# Build everything
pwsh ./toolkit/scripts/build.ps1

# Build a single app
pwsh ./toolkit/scripts/build.ps1 -SkipLibrary -SkipScreensavers -App helm

# Build release binaries for all 5 apps
pwsh ./toolkit/scripts/build.ps1 -SkipLibrary -SkipScreensavers -Release

# Cut a release
pwsh ./toolkit/scripts/release.ps1 -App helm -Version 3.0.26
pwsh ./toolkit/scripts/release.ps1 -All -Version 1.0.0

# Push a tag across all 9 repos (idempotent)
pwsh ./toolkit/scripts/push_all.ps1 -Tag v1.0.0
```

---

## Layout

```
toolkit/
├── README.md
├── LICENSE.md
├── scripts/
│   ├── build.ps1
│   ├── release.ps1
│   └── push_all.ps1
└── packaging/
    ├── deb/        (empty — cargo deb reads metadata from Cargo.toml)
    ├── rpm/        (empty — cargo generate-rpm reads metadata from Cargo.toml)
    └── desktop/    (empty — desktop entry templates are in each app repo)
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
