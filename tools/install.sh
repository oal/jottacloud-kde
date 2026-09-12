#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Install or upgrade the widget for the current user. No sudo is required.
set -euo pipefail

ID="io.github.oal.jottacloud-kde"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLED="$HOME/.local/share/plasma/plasmoids/$ID"
ICON_NAME="io.github.oal.jottacloud-kde"
ICON_SOURCE="$ROOT/contents/icons/$ICON_NAME.svg"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_TARGET="$ICON_DIR/$ICON_NAME.svg"
ACTION="auto"
RESTART=0

usage() {
    printf '%s\n' \
        'Usage: tools/install.sh [--upgrade|--remove|--restart]' \
        '' \
        '  (no args)   Install if absent, upgrade if already installed.' \
        '  --upgrade   Force the upgrade path.' \
        '  --remove    Uninstall the widget.' \
        '  --restart   Also restart plasmashell.'
}

restart_shell() {
    if systemctl --user --quiet is-active plasma-plasmashell.service 2>/dev/null; then
        systemctl --user restart plasma-plasmashell.service
    else
        kquitapp6 plasmashell 2>/dev/null || true
        sleep 2
        (setsid plasmashell >/dev/null 2>&1 &)
    fi
}

refresh_icon_cache() {
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

install_icon() {
    mkdir -p "$ICON_DIR"
    install -m 0644 "$ICON_SOURCE" "$ICON_TARGET"
    refresh_icon_cache
}

remove_icon() {
    rm -f "$ICON_TARGET"
    refresh_icon_cache
}

for arg in "$@"; do
    case "$arg" in
        --upgrade) ACTION="upgrade" ;;
        --remove) ACTION="remove" ;;
        --restart) RESTART=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 1 ;;
    esac
done

case "$ACTION" in
    remove)
        kpackagetool6 --type Plasma/Applet --remove "$ID"
        remove_icon
        printf '==> removed %s\n' "$ID"
        exit 0
        ;;
    upgrade)
        kpackagetool6 --type Plasma/Applet --upgrade "$ROOT"
        ;;
    auto)
        if [[ -d "$INSTALLED" ]]; then
            kpackagetool6 --type Plasma/Applet --upgrade "$ROOT"
        else
            kpackagetool6 --type Plasma/Applet --install "$ROOT"
        fi
        ;;
esac

install_icon
printf '==> installed to %s\n' "$INSTALLED"
if [[ "$RESTART" -eq 1 ]]; then
    restart_shell
else
    printf '%s\n' '==> Add it from: right-click the panel -> Add Widgets -> "Jottacloud status"'
    printf '%s\n' '    Use --restart after changing metadata.json.'
fi
