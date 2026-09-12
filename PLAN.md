# Jottacloud KDE Widget Plan

## Implementation Progress

- Phase 1 is complete in source: the standalone Plasma 6 package skeleton,
  sanitized fixture, generic host/container CLI documentation, and process
  boundary are present.
- Phase 2 is complete: CLI command construction, defensive status/detail
  parsing, state derivation, freshness, size formatting, error deduplication,
  and unit tests are implemented.
- Phases 3 and 4 are complete in source: compact state icon, responsive
  expandable dashboard, actions, notifications, backups, transfers, activity,
  and translations are implemented.
- Phase 5 requires verification on a Plasma host. Run the environment check,
  unit tests, QML lint, package build, installation, and manual acceptance
  checklist before release.

## Purpose

Create a Plasma 6 panel widget for Jottacloud that provides a useful status
indicator and a quick dashboard for the installed `jotta-cli` client.

The widget is a standalone project and follows established KDE Plasma
packaging and implementation patterns.

## Confirmed Scope

### Compact panel view

- A Jottacloud icon in the KDE panel.
- A state indicator that distinguishes at least:
  - not configured or unavailable
  - syncing/working
  - up to date/idle
  - paused
  - error/offline
- The icon and tooltip will communicate state without relying on color alone.
- The compact view will not show a large amount of text or storage numbers.

### Popup dashboard

The popup will use a summary-first layout with expandable sections:

- Account and device information.
- Storage usage and capacity, including a visual usage bar and readable values.
- Sync root, enabled/automatic state, current sync state, file counts, and
  progress for downloads/uploads when available.
- Read-only status for every configured backup folder.
- Current and recent upload/download transfer information where the CLI exposes
  it.
- Recent sync activity and errors.
- Last successful update time and any current CLI/connection error.

The first version will include these actions:

- Refresh now.
- Pause or resume sync indefinitely.
- Open the local sync folder.
- Open the Jottacloud web page.
- Open the widget configuration.

Sync pause will use the CLI's `syncpaused` setting. It will not pause backups
or the whole daemon. Backup folders will be displayed but not modified by the
widget.

### Notifications

- Notify on meaningful error transitions, such as the CLI becoming
  unavailable, authentication failing, or sync entering an error state.
- Deduplicate notifications so a polling cycle does not generate repeated
  notifications for the same problem.
- Do not notify for ordinary upload/download progress or normal completion.

### Localization and packaging

- Plasma 6 only, matching current KDE conventions.
- English and Norwegian Bokmal through Plasma's translation system.
- KPackage/Plasmoid packaging with install and package scripts.
- MPL-2.0 licensing.

## Findings

### Existing KDE project patterns

Established KDE Plasma widgets provide a good starting model:

- `metadata.json` declares a Plasma 6 `declarativeappletscript` widget.
- `contents/ui/main.qml` owns state, timers, actions, and representations.
- Pure JavaScript modules under `contents/code/` contain testable parsing and
  domain logic.
- QML owns the platform-specific transport boundary.
- Node tests cover the JavaScript without requiring a live Plasma shell.
- `qmllint`, `plasmawindowed`, and a manual panel checklist are already part of
  the development workflow.

The widget uses the same separation: command execution and raw CLI output are
isolated from state derivation and the QML presentation.

### Jottacloud CLI capabilities

Supported `jotta-cli` releases expose structured output for the core dashboard:

```text
jotta-cli status --json
jotta-cli list uploads --json
jotta-cli list downloads --json
```

`status --json` provides account/device metadata, capacity and usage, sync
configuration, sync counts and progress, upload/download state, and backup
state. The exact JSON shape will be captured as fixtures rather than assumed
to be stable in every release.

The relevant controls are:

```text
jotta-cli config syncpaused
jotta-cli config syncpaused true
jotta-cli config syncpaused false
jotta-cli sync log -n N
jotta-cli observe --sync
jotta-cli pause DURATION
jotta-cli resume
```

Only `config syncpaused true/false` will be used for the first-version pause
toggle. The daemon-wide `pause`/`resume` commands are intentionally excluded
from the UI.

References:

- <https://docs.jottacloud.com/en/articles/1437248-login-and-basic-use-with-jottacloud-cli>
- <https://docs.jottacloud.com/en/articles/1456057-how-to-view-the-status-and-logs-of-jottacloud-cli>
- <https://docs.jottacloud.com/en/articles/5859533-using-the-sync-folder-with-jottacloud-cli>
- <https://docs.jottacloud.com/en/articles/254735-how-to-pause-jottacloud-cli>
- <https://docs.jottacloud.com/en/articles/2750154-jottacloud-cli-configuration>

### Supported installation patterns

- A native host installation with a running `jottad` daemon.
- A container-backed installation with a non-interactive host wrapper.
- The configured command must be callable from the Plasma environment and
  must already have access to the user's normal CLI/daemon authentication.

The widget supports both a directly installed host CLI and a configured
container-backed wrapper where the host environment permits it. It must not
handle or store Jottacloud credentials; authentication remains the CLI/daemon's
responsibility.

## Proposed Architecture

### 1. CLI adapter boundary

Create a small adapter layer with one responsibility: execute approved
read-only or explicitly requested control commands and return normalized data
to the widget.

The adapter will:

- Invoke the configured `jotta-cli` executable without invoking a shell for
  arguments supplied by the widget.
- Apply a timeout to every command.
- Capture stdout and stderr separately.
- Reject non-zero exits with a typed error.
- Parse JSON only after validating that the command completed successfully.
- Normalize missing fields and unknown enum values into safe `unknown` states.
- Keep the last good dashboard snapshot so a transient poll failure can be
  displayed as stale rather than blank.
- Prevent overlapping polls and ignore results from superseded requests.

The default command should be `jotta-cli`, resolved from the Plasma process
environment. Configuration or a small setup helper may allow an explicit
absolute path for installations where the executable is not on that PATH.

### 2. QML-first process integration spike

Before adding new compiled code, verify whether the Plasma 6 runtime available
on the target system can reliably launch short-lived commands from QML and
deliver stdout/stderr and exit status. The spike must cover both a native
binary and the existing wrapper, not just a trivial command.

If the available Plasma/QML command facility is reliable, use it and keep the
widget dependency-free beyond Plasma, Qt, and the Jottacloud CLI.

If it cannot reliably execute, timeout, or monitor the CLI, add the smallest
possible local helper as a fallback. The helper should expose the same adapter
contract and should not become a second sync daemon. It may be a narrowly
scoped executable or script, but it must be justified by the spike and must
not require credentials or a new long-running service unless unavoidable.

### 3. Polling and state model

The root QML item will own a normalized dashboard snapshot and a small state
machine:

- `unconfigured`
- `unavailable`
- `offline`
- `error`
- `paused`
- `working`
- `upToDate`
- `unknown`

The state model will be derived from the structured status data, command exit
results, and freshness timestamps. Unknown future CLI states must remain
visible as `unknown` and must not be treated as successful or paused.

Polling will use a configurable local refresh interval with a conservative
default, plus an immediate refresh after a user action and when the popup is
opened. Transfer lists and sync activity can be fetched on popup opening or
when their sections are expanded to avoid unnecessary process launches while
the panel is idle.

The implementation will not use direct access to Jottacloud's private remote
API or daemon database. The CLI is the compatibility boundary.

### 4. QML UI structure

Likely files, subject to the process-integration spike:

- `metadata.json`
- `contents/ui/main.qml`
- `contents/ui/CompactRepresentation.qml`
- `contents/ui/FullRepresentation.qml`
- `contents/ui/DashboardSection.qml`
- `contents/ui/configGeneral.qml`
- `contents/config/config.qml`
- `contents/config/main.xml`
- `contents/code/cli.mjs`
- `contents/code/status.mjs`
- `contents/code/format.mjs`
- `tests/*.test.mjs`

The popup should use reusable section components rather than one large
unstructured column. Each section should have an explicit empty, loading,
stale, and error state. Long paths and error text must elide or wrap without
making the panel unusably wide.

The storage section should use a progress bar plus text, and the sync section
should make the distinction between local files, remote files, and currently
transferred files clear. The backup section should be clearly read-only.

### 5. User actions and safety

- Refresh launches a new status read unless one is already in flight.
- Pause sync runs `jotta-cli config syncpaused true`.
- Resume sync runs `jotta-cli config syncpaused false`.
- The action is disabled while the command is in flight and followed by a
  status refresh.
- The UI must never issue `sync reset`, `sync move`, `sync setup`, delete,
  archive, logout, or backup-removal commands.
- Opening the local folder must use a safe file URL derived from the CLI's
  reported root path; it must not pass user data through a shell command.
- Opening the web page should use `Qt.openUrlExternally`.
- Errors from actions must remain visible in the popup and be eligible for a
  deduplicated notification.

## Configuration

Initial configuration should be intentionally small:

- CLI executable path or command selection, defaulting to `jotta-cli`.
- Refresh interval.
- Whether to show the account/device section.
- Number of recent activity/error entries.
- Whether error notifications are enabled.

The widget should not ask the user to enter a login token. If the CLI is not
logged in, it should explain that authentication must be completed using the
normal CLI workflow.

## Container and service integration

The implementation phase will first reproduce the supported installation
paths:

1. Native `jotta-cli` and `jottad` on the host.
2. A container-backed daemon with a host wrapper.

The host-facing command must be reliable from a non-interactive Plasma process.
The wrapper may use an explicit supported container entrypoint or a host
package, but the existing service should keep owning daemon startup; the
widget must not start a second daemon.

Any setup change will be isolated, documented, and tested before it is used by
the widget. No credentials, daemon database files, or sync data will be moved
or rewritten.

## Testing and Verification

### Unit tests

Use Node tests for pure logic and fixture-based CLI output:

- Parse valid `status --json` output.
- Parse missing, null, and additional fields.
- Map known and unknown sync states.
- Calculate usage percentages and human-readable sizes.
- Derive paused, working, up-to-date, unavailable, stale, and error states.
- Parse upload/download lists and sync activity.
- Deduplicate equivalent errors.
- Verify command argument construction and action safety.
- Verify action results cannot overwrite a newer dashboard snapshot.

Fixtures contain only synthetic account data and placeholder paths; credentials
and live subscription data must never be committed.

### QML and packaging checks

- Run `qmllint` against all QML files.
- Run the complete Node test suite.
- Build the distributable Plasmoid package.
- Install and launch with `plasmawindowed`.
- Verify a clean install with no configured CLI or daemon.

### Manual acceptance checklist

1. Add the widget to a horizontal panel and confirm the compact icon is legible.
2. Confirm the popup opens on desktop and remains usable in a narrow panel.
3. Confirm storage usage and capacity are displayed from live JSON status.
4. Confirm working, up-to-date, paused, offline, and error states are visually
   distinct and understandable without color alone.
5. Confirm pause changes only `syncpaused`, leaves backups running, and changes
   back to resume after the command succeeds.
6. Confirm the setting persists when the daemon and Plasma shell are restarted.
7. Confirm the sync root opens in the file manager.
8. Confirm backup folders are visible but have no destructive controls.
9. Confirm transfer lists and recent activity refresh without freezing the
   popup.
10. Stop or make the CLI unavailable and confirm stale/error handling and one
    deduplicated notification.
11. Restore the daemon and confirm the widget recovers on the next refresh.
12. Test both the native CLI path and the container-backed wrapper.
13. Switch Plasma to Norwegian Bokmal and verify the widget translates.

## Delivery Phases

### Phase 1: Repository and integration spike

- [x] Create the Plasma package skeleton and project documentation.
- [ ] Confirm Plasma process execution options on the target host.
- [x] Document the host/container CLI invocation path and fail clearly when it
  is unavailable.
- [x] Add sanitized fixture-based JSON and text parsing coverage.
- [x] Add the narrowly scoped direct-exec helper because the executable data
  engine is a shell-command boundary.

### Phase 2: Adapter and state model

- [x] Implement command execution and timeout/error handling.
- [x] Implement JSON parsers and normalized dashboard state.
- [x] Add fixture-based tests before connecting the UI.

### Phase 3: First usable widget

- [x] Add compact panel state.
- [x] Add storage and sync summary sections.
- [x] Add refresh, pause/resume, local-folder, web, and configuration actions.
- [x] Add error notifications and translations.

### Phase 4: Full dashboard

- [x] Add read-only backups.
- [x] Add transfer queues, recent sync activity, and errors.
- [x] Add expandable sections, loading/stale states, and responsive sizing.

### Phase 5: Hardening and release packaging

- [ ] Test native and container-backed installations.
- [ ] Run unit tests, QML lint, and the manual acceptance checklist.
- [x] Build and verify the distributable Plasmoid package.
- [x] Document installation, CLI prerequisites, supported command paths, and
  known limitations.

## Non-Goals for Version One

- Replacing or reimplementing `jottad`.
- Direct Jottacloud API authentication in the widget.
- Starting, stopping, or restarting the daemon from the widget.
- Editing backup definitions.
- Moving, resetting, setting up, deleting, archiving, or logging out of sync.
- A general file browser or remote file manager.
- A long-running second daemon solely for the widget.
- Supporting Plasma 5.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| CLI JSON fields change between releases | Parse defensively, keep fixtures, expose unknown states, and record the tested CLI version. |
| QML cannot reliably run a wrapper or capture process output | Complete the process spike early; use the small helper fallback only if required. |
| Plasma's environment differs from an interactive shell | Use an explicit command configuration and test from `plasmashell`/`plasmawindowed`, not only from a terminal. |
| Container wrapper or required host tool is unavailable | Treat host/container invocation as a first-class installation test and provide a clear diagnostic in the widget. |
| Polling spawns too many CLI processes | Serialize requests, use sensible intervals, fetch detail lazily, and cache the last good snapshot. |
| A broad pause action surprises the user | Use only `syncpaused`; keep backup controls read-only. |
| Account data appears in logs or fixtures | Sanitize fixtures and keep credentials entirely inside the existing CLI/daemon. |

## Approval Gates Before Coding

The following choices are fixed by the interview unless changed after reading
this plan:

- New standalone Plasma 6 widget in `jottacloud-kde`.
- Full read-only dashboard, with sync-only pause/resume controls.
- Compact icon plus state, not a persistent storage percentage in the panel.
- Summary-first popup with expandable sections.
- English and Norwegian Bokmal.
- Native and container-backed CLI support where practical.
- QML-first implementation with a narrowly scoped helper fallback if required.

The only technical gate that must be resolved in Phase 1 is which process
execution path works reliably in the target Plasma installation. The UI and
domain model should not be built around an unverified command-execution
mechanism.
