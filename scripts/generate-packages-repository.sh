#!/bin/bash
# Builds DEB and RPM packages for all 17 projects and generates the APT/YUM repos.
# Pushes the static repository files back to the local76/packages GitHub repository.

set -e

PROJECTS=(
    "app-helm"
    "app-ignite"
    "app-pulse"
    "app-scout"
    "app-trance"
    "local76"
    "screensaver-beams"
    "screensaver-bounce"
    "screensaver-bursts"
    "screensaver-chaos"
    "screensaver-cosmos"
    "screensaver-disco"
    "screensaver-flame"
    "screensaver-glyphs"
    "screensaver-gnats"
    "screensaver-security"
    "screensaver-storm"
    "screensaver-tree"
)

ROOT_DIR="/home/jeryd/Projects"
REPO_DIR="$ROOT_DIR/packages"

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Error: local76/packages is not cloned at $REPO_DIR"
    exit 1
fi

DEB_DIR="$REPO_DIR/deb"
RPM_DIR="$REPO_DIR/rpm"

mkdir -p "$DEB_DIR/binary"
mkdir -p "$RPM_DIR"

echo "=========================================="
echo "Pulling latest changes from local76/packages..."
echo "=========================================="
(cd "$REPO_DIR" && git pull origin main)

echo "=========================================="
echo "Compiling and building all 17 packages..."
echo "=========================================="

for proj in "${PROJECTS[@]}"; do
    path="$ROOT_DIR/$proj"
    if [ -d "$path" ]; then
        echo -e "\n------------------------------------------"
        echo "Building DEB for $proj..."
        echo "------------------------------------------"
        (cd "$path" && cargo deb -o "$DEB_DIR/binary")

        echo -e "\n------------------------------------------"
        echo "Building RPM for $proj..."
        echo "------------------------------------------"
        if command -v cargo-generate-rpm >/dev/null 2>&1; then
            (cd "$path" && cargo generate-rpm -o "$RPM_DIR")
        else
            echo "Warning: cargo-generate-rpm is not installed. Skipping RPM build for $proj."
        fi
    else
        echo "Directory $path does not exist, skipping."
    fi
done

echo -e "\n=========================================="
echo "Generating Debian (DEB) Repository Indices..."
echo "=========================================="
cd "$DEB_DIR"
dpkg-scanpackages binary /dev/null > Packages
gzip -fk Packages

# Generate Release metadata
cat <<EOF > Release
Origin: Local76
Label: Local76 Software Repository
Suite: stable
Codename: stable
Architectures: amd64
Components: main
Description: Local76 applications and terminal screensavers
Date: $(date -R)
EOF

if command -v apt-ftparchive >/dev/null 2>&1; then
    apt-ftparchive release . >> Release
else
    # Simple checksum generation fallback if apt-utils is not fully installed
    echo "MD5Sum:" >> Release
    for f in Packages Packages.gz binary/*.deb; do
        if [ -f "$f" ]; then
            echo " $(md5sum "$f" | awk "{print \$1}") $(wc -c < "$f") $f" >> Release
        fi
    done
    echo "SHA256:" >> Release
    for f in Packages Packages.gz binary/*.deb; do
        if [ -f "$f" ]; then
            echo " $(sha256sum "$f" | awk "{print \$1}") $(wc -c < "$f") $f" >> Release
        fi
    done
fi

echo -e "\n=========================================="
echo "Generating YUM/RPM Repository Indices..."
echo "=========================================="
cd "$RPM_DIR"
if command -v createrepo >/dev/null 2>&1; then
    createrepo .
elif command -v createrepo_c >/dev/null 2>&1; then
    createrepo_c .
else
    echo "Warning: Neither createrepo nor createrepo_c is installed. YUM index generation skipped."
fi

# Generate local76.repo file for DNF/YUM configuration
cat <<EOF > local76.repo
[local76]
name=Local76 Software Repository
baseurl=https://local76.github.io/packages/rpm/
enabled=1
gpgcheck=1
gpgkey=https://local76.github.io/packages/local76.gpg
EOF

# GPG Signing
GPG_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep sec | head -n 1 | awk '{print $2}' | cut -d'/' -f2 || true)
if [ -n "$GPG_KEY" ]; then
    echo -e "\n=========================================="
    echo "Signing repositories with GPG Key: $GPG_KEY"
    echo "=========================================="
    
    # Sign Debian Repo
    cd "$DEB_DIR"
    gpg --default-key "$GPG_KEY" --clearsign -o InRelease Release
    gpg --default-key "$GPG_KEY" -abs -o Release.gpg Release
    
    # Sign RPM Repo
    cd "$RPM_DIR"
    if [ -f "repodata/repomd.xml" ]; then
        gpg --default-key "$GPG_KEY" --detach-sign --armor repodata/repomd.xml
    fi
    
    # Export public key for users
    gpg --armor --export "$GPG_KEY" > "$REPO_DIR/local76.gpg"
else
    echo -e "\n=========================================="
    echo "No GPG signing key detected. Skipping package signing."
    echo "=========================================="
fi

echo -e "\n=========================================="
echo "Committing and pushing repositories..."
echo "=========================================="
cd "$REPO_DIR"
git add -A
if ! git diff-index --quiet HEAD; then
    git commit -m "release: rebuild APT/YUM repositories with all 17 projects"
    git push origin main
    echo "Successfully updated and pushed local76/packages!"
else
    echo "No changes to commit."
fi
