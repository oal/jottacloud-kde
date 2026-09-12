#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Report host-side prerequisites without changing the user's installation.
set -u

missing=0
for command in kpackagetool6 plasmawindowed qmllint node; do
    if command -v "$command" >/dev/null 2>&1; then
        printf 'ok      %s -> %s\n' "$command" "$(command -v "$command")"
    else
        printf 'missing %s\n' "$command"
        missing=1
    fi
done

cli="${JOTTACLOUD_CLI:-jotta-cli}"
if command -v "$cli" >/dev/null 2>&1; then
    if "$cli" status --json >/dev/null 2>&1; then
        printf 'ok      CLI -> %s\n' "$(command -v "$cli")"
    else
        printf 'unusable CLI -> %s (status --json failed)\n' "$(command -v "$cli")"
        missing=1
    fi
else
    printf 'missing CLI -> %s\n' "$cli"
    missing=1
fi

if [[ "$missing" -ne 0 ]]; then
    printf '%s\n' 'The widget can be installed only after the missing host tools are available.' >&2
    exit 1
fi
