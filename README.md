# toolkit

Build, packaging, and release scripts for the local76 ecosystem. No Rust code, no GitHub Actions, no CI — every binary is built locally and uploaded to a GitHub Release by hand.

## Scripts

| Script | What it does |
|---|---|
| `scripts/build.ps1` | Builds every repo in dependency order: `library` → `screensavers` → the 5 apps. Supports `-SkipLibrary`, `-SkipScreensavers`, `-SkipApps`, `-Release`. |
| `scripts/release.ps1` | For one app or all (`-All`): builds release, copies to `dist/binaries/`, commits, tags `v$Version`, pushes, creates a draft GitHub Release with all artifacts attached. |

## Usage

From the monorepo root:

```pwsh
# Build everything
pwsh ./toolkit/scripts/build.ps1

# Build a single app
pwsh ./toolkit/scripts/build.ps1 -SkipLibrary -SkipScreensavers

# Cut a release
pwsh ./toolkit/scripts/release.ps1 -App helm -Version 1.0.0
pwsh ./toolkit/scripts/release.ps1 -All -Version 1.0.0
```

## Layout

```
toolkit/
├── README.md
├── LICENSE.md
├── scripts/
│   ├── build.ps1
│   └── release.ps1
└── packaging/
    ├── deb/        (empty — cargo deb reads metadata from Cargo.toml)
    ├── rpm/        (empty — cargo generate-rpm reads metadata from Cargo.toml)
    └── desktop/    (empty — desktop entry templates are in each app repo)
```

`packaging/` is intentionally empty. Each app's `Cargo.toml` carries the `[package.metadata.deb]` and `[package.metadata.generate-rpm]` metadata; `cargo deb` and `cargo generate-rpm` read it directly. The `.desktop` entries live in each app's `assets/` directory.

## Conventions

- **No GitHub Actions.** All builds are local. All releases are cut by hand.
- **No bash.** PowerShell Core (`pwsh`) is the only shell dependency. Runs on Windows and Linux.
- **No CI tokens.** The `gh` CLI uses your personal auth token.
- **No CI cache.** `cargo build --release` is fast enough (1-2 min per app) that no cache is needed.

## License

MIT.
