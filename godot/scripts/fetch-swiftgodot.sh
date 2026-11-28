#!/usr/bin/env bash
# Fetches the pinned SwiftGodot into godot/extension/vendor/SwiftGodot.
#
# It is a local checkout, not a URL dependency, because SwiftGodot sets
# compiler flags that SwiftPM refuses in a package fetched by URL.
set -euo pipefail

version="v0.99.2"
commit="d485324806b28f7567adf1f977acc9640d74a9dd"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$here/extension/vendor/SwiftGodot"

if [ -d "$dest/.git" ] && [ "$(git -C "$dest" rev-parse HEAD)" = "$commit" ] && git -C "$dest" diff --quiet; then
    echo "fetch-swiftgodot: $version already present"
    exit 0
fi
rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$version" https://github.com/migueldeicaza/SwiftGodot "$dest"
actual="$(git -C "$dest" rev-parse HEAD)"
if [ "$actual" != "$commit" ]; then
    echo "fetch-swiftgodot: $version is $actual, expected $commit" >&2
    exit 1
fi
echo "fetch-swiftgodot: $version"
