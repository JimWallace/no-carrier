#!/usr/bin/env bash
# Builds the Godot frontend: fetches the pinned SwiftGodot, builds the
# extension library, and copies it and the content JSON into the Godot
# project. Then open godot/project in Godot 4.7.
#
# Usage: godot/scripts/build.sh [debug|release] [swift build options]
# For example, a universal Mac build:
#   godot/scripts/build.sh release --arch arm64 --arch x86_64
set -euo pipefail

configuration="${1:-debug}"
shift || true
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="$(cd "$here/.." && pwd)"

"$here/scripts/fetch-swiftgodot.sh"

cd "$here/extension"
swift build -c "$configuration" "$@"
products="$(swift build -c "$configuration" "$@" --show-bin-path)"

case "$(uname -s)" in
    Darwin) library="libCarrierGodot.dylib" ;;
    *) library="libCarrierGodot.so" ;;
esac

mkdir -p "$here/project/bin" "$here/project/content"
cp "$products/$library" "$here/project/bin/$library"
cp "$repo"/Sources/CarrierContent/Content/*.json "$here/project/content/"
echo "build: $here/project/bin/$library and the content are in place"
