/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.notification
import org.kde.kirigami as Kirigami

import "../code/cli.mjs" as Cli
import "../code/status.mjs" as Status
import "../code/format.mjs" as Format

PlasmoidItem {
    id: root

    property var snapshot: Status.emptySnapshot()
    property bool hasSnapshot: false
    property string dashboardState: Status.STATE.UNKNOWN
    property string lastError: ""
    property string detailError: ""
    property string transferError: ""
    property string activityError: ""
    property double lastSuccessMs: 0
    property bool polling: false
    property bool actionInFlight: false
    property bool detailsLoading: false
    property string activeCommand: ""
    property int activeRequestId: 0
    property bool desiredPause: false
    property var detailQueue: []
    property string lastNotificationKey: ""
    property bool errorStatePinned: false

    readonly property string cliExecutable: Cli.executableOrDefault(plasmoid.configuration.cliExecutable)
    readonly property int pollMs: Math.max(10, Number(plasmoid.configuration.refreshIntervalSeconds)) * 1000
    readonly property int recentLimit: Math.max(1, Number(plasmoid.configuration.recentEntries))
    readonly property bool commandBusy: transport.busy
    readonly property bool desktopFormFactor: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property bool detailsVisible: expanded || desktopFormFactor
    readonly property bool compactStorageEnabled: plasmoid.configuration.showCompactStorage !== false
    readonly property bool compactTransfersEnabled: plasmoid.configuration.showCompactTransfers !== false
    readonly property string brandIconName: "io.github.oal.jottacloud-kde"
    readonly property url brandIconSource: Qt.resolvedUrl("../icons/io.github.oal.jottacloud-kde.svg")
    readonly property string webUrl: plasmoid.configuration.webUrl || "https://www.jottacloud.com/web/secure"

    Binding {
        target: root
        property: "width"
        when: root.desktopFormFactor
        value: Kirigami.Units.gridUnit * 16
        restoreMode: Binding.RestoreBinding
    }

    Binding {
        target: root
        property: "height"
        when: root.desktopFormFactor
        value: Kirigami.Units.gridUnit * 28
        restoreMode: Binding.RestoreBinding
    }

    property QtObject transport: CliTransport {
        executable: root.cliExecutable
        timeoutMs: 12000
        onFinished: function (requestId, exitCode, stdout, stderr) {
            root.commandFinished(requestId, exitCode, stdout, stderr);
        }
    }

    preferredRepresentation: root.desktopFormFactor ? fullRepresentation : compactRepresentation
    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    toolTipMainText: i18n("Jottacloud status")
    toolTipSubText: root.tooltipText()

    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    Timer {
        id: pollTimer
        interval: root.pollMs
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: freshnessTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.updateFreshness()
    }

    Connections {
        target: plasmoid.configuration

        function onCliExecutableChanged() { root.refresh() }
        function onRefreshIntervalSecondsChanged() { pollTimer.restart() }
    }

    onDetailsVisibleChanged: {
        if (detailsVisible) {
            root.refresh();
            root.requestDetails();
        }
    }

    Component.onCompleted: root.refresh()

    function refresh() {
        if (transport.busy)
            return;
        polling = true;
        activeCommand = "status";
        activeRequestId = transport.run(Cli.argsFor(Cli.OPERATION.STATUS));
    }

    function updateFreshness() {
        if (!hasSnapshot || polling || actionInFlight || errorStatePinned)
            return;
        const nextState = Status.deriveState({ snapshot: snapshot, pollMs: pollMs });
        if (nextState !== dashboardState) {
            dashboardState = nextState;
            if (!Status.isErrorState(dashboardState))
                lastNotificationKey = "";
        }
    }

    function requestDetails() {
        if (!detailsVisible || transport.busy)
            return;
        detailQueue = [Cli.OPERATION.UPLOADS, Cli.OPERATION.DOWNLOADS, Cli.OPERATION.ACTIVITY];
        detailError = "";
        transferError = "";
        activityError = "";
        detailsLoading = true;
        runNextDetail();
    }

    function runNextDetail() {
        if (transport.busy || detailQueue.length === 0) {
            if (!transport.busy && detailQueue.length === 0)
                detailsLoading = false;
            return;
        }
        const queue = detailQueue.slice();
        activeCommand = queue.shift();
        detailQueue = queue;
        const args = activeCommand === Cli.OPERATION.ACTIVITY
            ? Cli.argsFor(activeCommand, recentLimit)
            : Cli.argsFor(activeCommand);
        activeRequestId = transport.run(args);
    }

    function runPauseAction() {
        if (transport.busy || !hasSnapshot || !snapshot.sync.configured)
            return;
        desiredPause = !snapshot.sync.paused;
        actionInFlight = true;
        activeCommand = Cli.OPERATION.SET_PAUSED;
        activeRequestId = transport.run(Cli.argsFor(activeCommand, desiredPause));
    }

    function commandFinished(requestId, exitCode, stdout, stderr) {
        if (!Cli.isCurrentRequest(requestId, activeRequestId))
            return;

        const command = activeCommand;
        if (command === "status")
            polling = false;

        if (command === Cli.OPERATION.SET_PAUSED) {
            actionInFlight = false;
            if (Number(exitCode) !== 0) {
                handleFailure(Cli.resultError({ exitCode, stdout, stderr }), true);
                return;
            }
            lastError = "";
            refresh();
            return;
        }

        if (Number(exitCode) !== 0) {
            const failure = Cli.resultError({ exitCode, stdout, stderr });
            if (command === "status") {
                handleFailure(failure, false);
            } else {
                recordDetailFailure(command, failure.message);
                lastError = failure.message;
                runNextDetail();
            }
            return;
        }

        try {
            const value = command === Cli.OPERATION.ACTIVITY
                ? Cli.parseActivity(stdout) : Cli.parseJson(stdout);
            if (command === "status")
                acceptStatus(value);
            else
                acceptDetails(command, value);
        } catch (error) {
            if (command === "status")
                handleFailure(error, false);
            else {
                const detailMessage = error.message || String(error);
                recordDetailFailure(command, detailMessage);
                lastError = detailMessage;
                runNextDetail();
            }
        }
    }

    function acceptStatus(value) {
        const next = Status.normalizeStatus(value);
        next.receivedAt = Date.now();
        snapshot = next;
        hasSnapshot = true;
        lastSuccessMs = next.receivedAt;
        lastError = next.currentError ? next.currentError.message : "";
        errorStatePinned = false;
        dashboardState = Status.deriveState({ snapshot: next, pollMs: pollMs });
        if (!Status.isErrorState(dashboardState))
            lastNotificationKey = "";
        else if (lastError)
            notifyError(dashboardState, lastError);

        if (detailsVisible)
            requestDetails();
    }

    function acceptDetails(command, value) {
        const next = Object.assign({}, snapshot, {
            transfers: Object.assign({}, snapshot.transfers),
            activity: snapshot.activity.slice(),
        });
        if (command === Cli.OPERATION.UPLOADS)
            next.transfers.uploads = Status.normalizeStatus({ uploads: value }).transfers.uploads;
        else if (command === Cli.OPERATION.DOWNLOADS)
            next.transfers.downloads = Status.normalizeStatus({ downloads: value }).transfers.downloads;
        else
            next.activity = Status.normalizeStatus({ activity: value }).activity.slice(0, recentLimit);
        snapshot = next;
        runNextDetail();
    }

    function handleFailure(error, fromAction) {
        const failure = error || new Error(i18n("The Jottacloud command failed"));
        lastError = failure.message || String(failure);
        if (activeCommand === "status" || fromAction)
            errorStatePinned = true;
        dashboardState = Status.deriveState({
            snapshot: hasSnapshot ? snapshot : null,
            commandError: failure,
            pollMs: pollMs,
        });
        if (fromAction)
            detailError = lastError;
        notifyError(dashboardState, lastError);
    }

    function recordDetailFailure(command, message) {
        detailError = message;
        if (command === Cli.OPERATION.ACTIVITY)
            activityError = message;
        else
            transferError = message;
    }

    function notifyError(failureState, message) {
        if (!plasmoid.configuration.notificationsEnabled || !Status.isErrorState(failureState))
            return;
        const key = `${failureState}|${String(message).replace(/\s+/g, ' ').trim().toLowerCase()}`;
        if (!key || key === lastNotificationKey)
            return;
        lastNotificationKey = key;
        errorNotification.text = message;
        errorNotification.sendEvent();
    }

    function stateText(value) {
        switch (value) {
        case Status.STATE.UNCONFIGURED: return i18n("Not configured");
        case Status.STATE.UNAVAILABLE: return i18n("CLI unavailable");
        case Status.STATE.OFFLINE: return i18n("Offline");
        case Status.STATE.ERROR: return i18n("Error");
        case Status.STATE.PAUSED: return i18n("Sync paused");
        case Status.STATE.WORKING: return i18n("Syncing");
        case Status.STATE.UP_TO_DATE: return i18n("Up to date");
        case Status.STATE.STALE: return i18n("Stale data");
        default: return i18n("Unknown status");
        }
    }

    function stateIcon(value) {
        switch (value) {
        case Status.STATE.WORKING: return "view-refresh";
        case Status.STATE.UP_TO_DATE: return "cloud";
        case Status.STATE.PAUSED: return "media-playback-pause";
        case Status.STATE.ERROR: return "dialog-error";
        case Status.STATE.UNAVAILABLE: return "dialog-warning";
        case Status.STATE.OFFLINE: return "network-offline";
        case Status.STATE.UNCONFIGURED: return "configure";
        default: return "help-about";
        }
    }

    function stateSymbol(value) {
        switch (value) {
        case Status.STATE.WORKING: return "~";
        case Status.STATE.UP_TO_DATE: return "=";
        case Status.STATE.PAUSED: return "||";
        case Status.STATE.ERROR: return "!";
        case Status.STATE.UNAVAILABLE: return "!";
        case Status.STATE.OFFLINE: return "x";
        case Status.STATE.UNCONFIGURED: return "-";
        case Status.STATE.STALE: return "?";
        default: return "?";
        }
    }

    function stateColor(value) {
        switch (value) {
        case Status.STATE.UP_TO_DATE: return "positive";
        case Status.STATE.WORKING: return "neutral";
        case Status.STATE.PAUSED: return "neutral";
        case Status.STATE.ERROR:
        case Status.STATE.UNAVAILABLE:
        case Status.STATE.OFFLINE: return "negative";
        default: return "disabled";
        }
    }

    function tooltipText() {
        const headline = stateText(dashboardState);
        if (lastError)
            return `${headline}: ${lastError}`;
        if (snapshot.sync.rootPath)
            return `${headline} - ${snapshot.sync.rootPath}`;
        return headline;
    }

    function lastUpdatedText() {
        if (!lastSuccessMs)
            return i18n("No successful update yet");
        return i18nc("%1 is a local time", "Updated %1", Qt.formatTime(
            new Date(lastSuccessMs), Qt.locale(), Locale.ShortFormat));
    }

    function storageSummary() {
        const used = Format.formatBytes(snapshot.storage.usedBytes);
        const capacity = snapshot.storage.capacityBytes === null
            ? (snapshot.storage.unlimited ? i18n("Unlimited") : i18n("Unknown"))
            : Format.formatBytes(snapshot.storage.capacityBytes);
        return `${used} / ${capacity}`;
    }

    function storagePercentageText() {
        const ratio = Format.formatPercent(snapshot.storage.usedBytes,
                                           snapshot.storage.capacityBytes);
        return ratio === null ? "" : `${Math.round(ratio * 100)}%`;
    }

    function compactStorageText() {
        return Format.formatCompactStorage(snapshot.storage.usedBytes,
                                           snapshot.storage.capacityBytes);
    }

    function storageSummaryWithPercent() {
        const percentage = storagePercentageText();
        return percentage ? `${storageSummary()} (${percentage})` : storageSummary();
    }

    function activeTransfer(direction) {
        return direction === "upload" ? snapshot.sync.upload : snapshot.sync.download;
    }

    function hasActiveTransfer(direction) {
        return activeTransfer(direction) !== null;
    }

    function transferSummaryText(direction) {
        const transfer = activeTransfer(direction);
        if (!transfer)
            return "";
        const action = direction === "upload" ? i18n("Uploading") : i18n("Downloading");
        const name = transfer.name || transfer.path;
        const rate = Format.formatRate(transfer.rateBytesPerSecond);
        const details = [];
        if (name)
            details.push(name);
        if (rate)
            details.push(rate);
        return details.length > 0 ? `${action}: ${details.join(" - ")}` : action;
    }

    function transferTooltipText() {
        const transfers = [];
        if (hasActiveTransfer("upload"))
            transfers.push(transferSummaryText("upload"));
        if (hasActiveTransfer("download"))
            transfers.push(transferSummaryText("download"));
        return transfers.length > 0 ? transfers.join("\n") : i18n("No active transfers");
    }

    function openSyncFolder() {
        const url = Format.fileUrl(snapshot.sync.rootPath);
        if (url)
            Qt.openUrlExternally(url);
    }

    function openWeb() {
        Qt.openUrlExternally(webUrl);
    }

    Notification {
        id: errorNotification
        componentName: "plasma_workspace"
        eventId: "notification"
        iconName: root.brandIconName
        title: i18n("Jottacloud status")
        urgency: Notification.NormalUrgency
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        },
        PlasmaCore.Action {
            text: root.snapshot.sync.paused ? i18n("Resume sync") : i18n("Pause sync")
            icon.name: root.snapshot.sync.paused ? "media-playback-start" : "media-playback-pause"
            enabled: root.hasSnapshot && root.snapshot.sync.configured && !root.commandBusy
            onTriggered: root.runPauseAction()
        }
    ]

    Component.onDestruction: transport.cancel()
}
