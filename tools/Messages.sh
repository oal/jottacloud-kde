#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="plasma_applet_io.github.jottacloud-kde"
POT="$ROOT/po/$DOMAIN.pot"

if ! command -v xgettext >/dev/null 2>&1; then
    printf '%s\n' 'xgettext is required to regenerate the message template' >&2
    exit 1
fi

cd "$ROOT"
mkdir -p po
files=(contents/ui/*.qml contents/code/*.mjs)
xgettext --from-code=UTF-8 --language=JavaScript \
    --keyword=i18n:1 --keyword=i18nc:1c,2 \
    --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
    --package-name="Jottacloud status" \
    --copyright-holder="Jottacloud KDE contributors" \
    -o "$POT" "${files[@]}"
printf '==> %s\n' "$POT"
