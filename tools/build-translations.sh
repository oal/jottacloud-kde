#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="plasma_applet_io.github.jottacloud-kde"

if ! command -v msgfmt >/dev/null 2>&1; then
    printf '%s\n' '==> msgfmt not found, skipping translation build' >&2
    exit 0
fi

shopt -s nullglob
for po in "$ROOT"/po/*.po; do
    lang="$(basename "$po" .po)"
    destination="$ROOT/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$destination"
    msgfmt "$po" -o "$destination/$DOMAIN.mo"
    printf '==> built %s catalog\n' "$lang"
done
