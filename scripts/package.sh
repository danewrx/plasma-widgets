#!/bin/sh
# Builds <widget id>-<version>.plasmoid (a zip with metadata.json at its root) into ./dist and prints its path.
# Usage: scripts/package.sh <widget folder>
set -eu
dir=${1:?usage: scripts/package.sh <widget folder>}
id=$(jq -r .KPlugin.Id "$dir/metadata.json")
version=$(jq -r .KPlugin.Version "$dir/metadata.json")
mkdir -p dist
out="$(pwd)/dist/$id-$version.plasmoid"
rm -f "$out"
python3 - "$dir" "$out" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1:3]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d != ".git"]
        for f in sorted(files):
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, src))
PY
echo "$out"
