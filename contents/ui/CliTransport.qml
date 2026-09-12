/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

import "../code/cli.mjs" as Cli

/*
 * QML owns the process callback for the same reason Entur's transport owns
 * XMLHttpRequest callbacks: callbacks installed from an ES module are not
 * delivered by the QML runtime. Plasma's executable data engine runs a short
 * lived command and gives us stdout, stderr, and its exit code.
 *
 * The data engine takes a command line rather than argv. cli.mjs quotes every
 * part before it reaches this object. A fixed helper then invokes the selected
 * CLI directly with argv, avoiding a second shell parse of CLI arguments. This
 * object serializes commands and applies the timeout so the widget never
 * accumulates daemon queries.
 */
QtObject {
    id: transport

    property string executable: "jotta-cli"
    property int timeoutMs: Cli.DEFAULT_TIMEOUT_MS
    property bool busy: false
    property int nextRequestId: 0
    property int activeRequestId: 0
    property string activeSource: ""
    readonly property string helperPath: decodeURIComponent(
        Qt.resolvedUrl("../helper/exec-cli").toString().replace(/^file:\/\//, ""))

    signal finished(int requestId, int exitCode, string stdout, string stderr)

    property Plasma5Support.DataSource executableSource: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            if (!transport.busy || sourceName !== transport.activeSource)
                return;
            transport.consume(sourceName, data || ({}));
        }
    }

    property Timer timeoutTimer: Timer {
        repeat: false
        interval: transport.timeoutMs
        onTriggered: transport.timeout()
    }

    function stringValue(value) {
        return value === undefined || value === null ? "" : String(value);
    }

    function finish(exitCode, stdout, stderr) {
        if (!busy)
            return;
        const requestId = activeRequestId;
        const sourceName = activeSource;
        busy = false;
        activeSource = "";
        timeoutTimer.stop();
        if (sourceName)
            executableSource.disconnectSource(sourceName);
        finished(requestId, Number.isFinite(Number(exitCode)) ? Number(exitCode) : -1,
                 stringValue(stdout), stringValue(stderr));
    }

    function consume(sourceName, data) {
        const exitCode = data["exit code"] !== undefined
            ? data["exit code"]
            : (data.exitCode !== undefined ? data.exitCode : data["exit status"]);
        // Executable data sources may publish an intermediate update.
        if (exitCode === undefined)
            return;
        finish(exitCode, data.stdout, data.stderr || data.error);
    }

    function timeout() {
        if (!busy)
            return;
        finish(-1, "", "jotta-cli request timed out");
    }

    /** @returns {number} request id, or 0 when a command is already running. */
    function run(args) {
        if (busy || !Array.isArray(args))
            return 0;
        const sourceName = Cli.commandLine("/bin/sh", [helperPath, executable, ...args]);
        nextRequestId += 1;
        activeRequestId = nextRequestId;
        activeSource = sourceName;
        busy = true;
        timeoutTimer.interval = Math.max(1000, timeoutMs);
        timeoutTimer.start();
        try {
            executableSource.connectSource(sourceName);
        } catch (error) {
            finish(-1, "", error && error.message ? error.message : String(error));
        }
        return activeRequestId;
    }

    function cancel() {
        if (!busy)
            return;
        finish(-1, "", "jotta-cli request cancelled");
    }
}
