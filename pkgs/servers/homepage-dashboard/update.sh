#!/usr/bin/env nix-shell
#!nix-shell -I nixpkgs=./. -i bash -p curl jq nix-prefetch-github yj git pnpm_10
# shellcheck shell=bash

set -euo pipefail

cd $(readlink -e $(dirname "${BASH_SOURCE[0]}"))

# Generate the patch file that makes homepage-dashboard aware of the NIXPKGS_HOMEPAGE_CACHE_DIR environment variable.
# Generating the patch this way ensures that both the patch is included, and the lock file is updated.
generate_patch() {
    git clone https://github.com/gethomepage/homepage-dashboard.git src
    pushd src

    pnpm install
    pnpm patch next
    sd \
      'this.serverDistDir = ctx.serverDistDir;' \
      'this.serverDistDir = require("path").join((process.env.NIXPKGS_HOMEPAGE_CACHE_DIR || "/var/cache/homepage-dashboard"), "homepage");' \
      node_modules/.pnpm_patches/next*/dist/server/lib/incremental-cache/file-system-cache.js
    pnpm patch-commit node_modules/.pnpm_patches/next*

    git add -A .
    git diff -p --staged > ../prerender_cache_path.patch

    popd
    rm -rf src
}

# Update the hash of the homepage-dashboard source code in the Nix expression.
update_homepage_dashboard_source() {
    local version; version="$1"
    echo "Updating homepage-dashboard source"

    sri_hash="$(nix-prefetch-github gethomepage homepage --rev "refs/tags/v${version}" | jq -r '.hash')"

    sed -i "s|version = \".*$|version = \"$version\";|" package.nix
    sed -i "s|hash = \".*$|hash = \"${sri_hash}\";|1" package.nix
}

update_pnpm_deps_hash() {
    nix-build --expr 'let src = (import ./default.nix {}).homepage-dashboard.pnpmDeps; in (src.overrideAttrs or (f: src // f src)) (_: { outputHash = ""; outputHashAlgo = "sha256"; })' 2>&1 | tr -s ' ' | grep -Po "got: \K.+$"
}

LATEST_TAG="$(curl -s ${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} https://api.github.com/repos/gethomepage/homepage/releases/latest | jq -r '.tag_name')"
LATEST_VERSION="$(expr "$LATEST_TAG" : 'v\(.*\)')"
CURRENT_VERSION="$(grep -Po "version = \"\K[^\"]+" default.nix)"

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "homepage-dashboard is up to date: ${CURRENT_VERSION}"
    exit 0
fi

update_homepage_dashboard_source "$LATEST_VERSION"
generate_patch "$LATEST_VERSION"
update_pnpm_deps_hash
