#!/usr/bin/env bash
# Fetches the pinned SwiftGodot into godot/extension/vendor/SwiftGodot and
# lowers its macOS floor from 14 to 13.
#
# Why the patch: SwiftGodot declares macOS 14, but uses no macOS 14 API
# (checked at the pinned commit). The maintainer's Mac runs macOS 13, and
# SwiftPM refuses a dependency whose floor is above the package's. CI builds
# the extension with a macOS 13 deployment target, so an API that needs 14
# fails that build instead of failing on the player's machine.
set -euo pipefail

version="v0.99.2"
commit="d485324806b28f7567adf1f977acc9640d74a9dd"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$here/extension/vendor/SwiftGodot"

if [ -d "$dest/.git" ] && [ "$(git -C "$dest" rev-parse HEAD)" = "$commit" ]; then
    echo "fetch-swiftgodot: $version already present"
else
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$version" https://github.com/migueldeicaza/SwiftGodot "$dest"
    actual="$(git -C "$dest" rev-parse HEAD)"
    if [ "$actual" != "$commit" ]; then
        echo "fetch-swiftgodot: $version is $actual, expected $commit" >&2
        exit 1
    fi
fi

manifest="$dest/Package.swift"
if grep -q '\.macOS(\.v14)' "$manifest"; then
    sed -i.orig 's/\.macOS(\.v14)/.macOS(.v13)/' "$manifest"
    rm -f "$manifest.orig"
fi
grep -q '\.macOS(\.v13)' "$manifest" || {
    echo "fetch-swiftgodot: could not set the macOS floor in $manifest" >&2
    exit 1
}
echo "fetch-swiftgodot: $version at macOS 13"
