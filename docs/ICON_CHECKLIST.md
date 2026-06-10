# Icon Checklist

Pre-ship checklist for any new (or newly-migrated) tool in the local76
ecosystem. Run all six before tagging a release.

---

## 1. Source ICO has the right 4 sizes

The brand `app.ico` (or per-scene `assets/icon.ico`) must contain exactly
**16×16, 32×32, 48×48, 256×256 at 32-bpp RGBA** per
[`library/docs/VISUAL_STANDARDS.md`](../library/docs/VISUAL_STANDARDS.md) § B.

```powershell
$ico = "path/to/your.ico"
$bytes = [System.IO.File]::ReadAllBytes($ico)
$count = [BitConverter]::ToUInt16($bytes, 4)
$sizes = for ($i = 0; $i -lt $count; $i++) {
    $p = 6 + ($i * 16)
    $w = if ($bytes[$p] -eq 0) { 256 } else { $bytes[$p] }
    $h = if ($bytes[$p+1] -eq 0) { 256 } else { $bytes[$p+1] }
    $bpp = [BitConverter]::ToUInt16($bytes, $p + 6)
    "{0}x{1}@{2}bpp" -f $w, $h, $bpp
}
$sizes -join ", "
```

**Pass:** the 4 expected sizes are listed, all 32bpp.

## 2. build.rs uses `library::build_resources` (or `embed-resource` 2.x)

`winres 0.1.x` is deprecated. The 0.1.x parser mangles PNG-compressed
multi-size ICOs.

In `build.rs`:

```rust
if let Some((icon_path, meta)) = library::build_resources::prepare_icon("assets/brand/app.ico") {
    let mut rc = embed_resource::new();
    rc.set_icon(&icon_path);
    rc.set("FileDescription", &meta.file_description);
    rc.set("ProductName",     library::build_resources::DEFAULT_PRODUCT_NAME);
    rc.set("CompanyName",     library::build_resources::DEFAULT_COMPANY_NAME);
    rc.set("LegalCopyright",  library::build_resources::DEFAULT_LEGAL_COPYRIGHT);
    rc.compile().expect("failed to compile winres resource");
}
```

**Pass:** no `winres::WindowsResource` calls remain; the build.rs
references `library::build_resources::prepare_icon`.

## 3. Cargo.toml declares the new build-dep

```toml
[target.'cfg(windows)'.build-dependencies]
embed-resource = "2"
```

**Pass:** the `[build-dependencies]` block (or the
`[target.'cfg(windows)'.build-dependencies]` block) contains
`embed-resource = "2"` and does **not** contain a non-optional
`winres = "0.1"`. (If the old `winres` is kept for back-compat, it
must be `optional = true`.)

## 4. Linux hicolor PNG install is in the deb/rpm asset arrays

In each consuming `Cargo.toml`:

```toml
[package.metadata.deb]
assets = [
    ["target/release/<name>", "usr/bin/<name>", "755"],
    ["assets/brand/app_icon.png", "usr/share/pixmaps/<name>.png", "644"],
    ["assets/<name>.desktop", "usr/share/applications/<name>.desktop", "644"],
    # ^-- PNG must be installed for the .desktop's Icon= key to resolve.
]

[package.metadata.generate-rpm]
assets = [
    { source = "target/release/<name>", dest = "/usr/bin/<name>", mode = "755" },
    { source = "assets/brand/app_icon.png", dest = "/usr/share/pixmaps/<name>.png", mode = "644" },
    { source = "assets/<name>.desktop", dest = "/usr/share/applications/<name>.desktop", mode = "644" },
]
```

**Pass:** both arrays include a line that copies
`assets/brand/app_icon.png` (or per-scene equivalent) to
`/usr/share/pixmaps/<name>.png` **and** the corresponding
`/usr/share/icons/hicolor/256x256/apps/<name>.png` if the new
hicolor-based convention is in use.

## 5. Source `.desktop` has the correct `Icon=` key

The `.desktop` file's `Icon=` value must match the installed PNG's
basename. For freedesktop hicolor installs, prefer
`/usr/share/icons/hicolor/256x256/apps/<name>.png` (absolute path) or
just `<name>` (the icon theme will resolve it).

**Pass:** `Icon=<name>` (or absolute path), and the file at that path
exists in the package's file list (item 4).

## 6. `verify-icon.ps1` reports PASS

After `cargo build --release`, run:

```powershell
pwsh ./toolkit/scripts/verify-icon.ps1 -BinDir dist/binaries
```

**Pass:** every binary in `dist/binaries` (or the relevant subfolder)
shows `Verdict = PASS` and `Valid32bpp >= 4`.

---

## Quick smoke test

```powershell
# from the repo root
pwsh ./toolkit/scripts/migrate-winres.ps1 -Root . -Binaries ./dist/binaries
```

This rewrites every stale `build.rs` and `Cargo.toml` in the tree
(idempotently), rebuilds, and re-verifies.
