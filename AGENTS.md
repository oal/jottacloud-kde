# Development Commands

Run `node --test tests/*.test.mjs` for the complete pure-logic suite. Run
`./tools/check-environment.sh` before installing. On a Plasma host, lint each
QML file with `qmllint`, build with `./tools/package.sh`, and use
`plasmawindowed io.github.oal.jottacloud-kde` before adding the widget to a panel.

Restart `plasmashell` after changing `metadata.json` or an ES module because
Plasma caches package metadata and loaded modules.

The static project site lives in `docs/` and is published with GitHub Pages
from the `main` branch `/docs` folder. Preview it with
`python3 -m http.server -d docs`.

The current project intentionally never invokes `sync reset`, `sync move`,
`sync setup`, delete, archive, logout, or backup-removal commands.
