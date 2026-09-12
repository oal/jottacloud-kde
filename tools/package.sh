#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Build a distributable KPackage archive.
set -euo pipefail

ID="io.github.oal.jottacloud-kde"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist/$ID.plasmoid"

"$ROOT/tools/build-translations.sh"
mkdir -p "$ROOT/dist"
rm -f "$OUT"

cd "$ROOT"
zip -r -q "$OUT" metadata.json contents \
    -x '*.po' '*.pot' '*/.*'

echo "==> $OUT"
unzip -l "$OUT"
