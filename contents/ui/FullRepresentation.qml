/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "../code/format.mjs" as Format

PlasmaExtras.Representation {
    id: full

    readonly property bool wideLayout: width >= Kirigami.Units.gridUnit * 34

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 15
    Layout.preferredWidth: Kirigami.Units.gridUnit * 16
    Layout.preferredHeight: Kirigami.Units.gridUnit * 28
    Layout.maximumWidth: Kirigami.Units.gridUnit * 20
    width: root.desktopFormFactor ? Kirigami.Units.gridUnit * 16
                                  : Kirigami.Units.gridUnit * 16
    height: root.desktopFormFactor ? Kirigami.Units.gridUnit * 32
                                   : Kirigami.Units.gridUnit * 28
    collapseMarginsHint: true

    function syncFilesText() {
        const sync = root.snapshot.sync;
        const parts = [];
        if (sync.localFiles !== null)
            parts.push(i18nc("%1 is a file count", "%1 local", Format.formatCount(sync.localFiles)));
        if (sync.remoteFiles !== null)
            parts.push(i18nc("%1 is a file count", "%1 remote", Format.formatCount(sync.remoteFiles)));
        if (sync.totalFiles !== null && parts.length === 0)
            parts.push(i18nc("%1 is a file count", "%1 files", Format.formatCount(sync.totalFiles)));
        return parts.join(" - ");
    }

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.brandIconSource
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: i18n("Jottacloud")
                    elide: Text.ElideRight
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.stateText(root.dashboardState)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                    elide: Text.ElideRight
                }
            }

            PlasmaComponents.ToolButton {
                id: refreshButton
                icon.name: "view-refresh"
                text: i18n("Refresh now")
                enabled: !root.commandBusy
                onClicked: root.refresh()
                PlasmaComponents.ToolTip { text: refreshButton.text }
            }

            PlasmaComponents.ToolButton {
                id: configureButton
                icon.name: "configure"
                text: i18n("Configure Jottacloud")
                onClicked: Plasmoid.internalAction("configure").trigger()
                PlasmaComponents.ToolTip { text: configureButton.text }
            }
        }
    }

    contentItem: PlasmaComponents.ScrollView {
        id: scroll
        clip: true

        GridLayout {
            id: column
            width: scroll.availableWidth
            columns: full.wideLayout ? 2 : 1
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.columnSpan: full.wideLayout ? 2 : 1
                visible: !root.hasSnapshot
                iconName: root.stateIcon(root.dashboardState)
                text: root.stateText(root.dashboardState)
                explanation: root.lastError || i18n("Waiting for a status response from jotta-cli.")
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.columnSpan: full.wideLayout ? 2 : 1
                visible: root.hasSnapshot
                implicitHeight: overviewGrid.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1

                GridLayout {
                    id: overviewGrid
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    columns: full.wideLayout ? 2 : 1
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: i18n("Storage used")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.75
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: root.storageSummaryWithPercent()
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        QQC2.ProgressBar {
                            Layout.fillWidth: true
                            visible: Format.formatPercent(root.snapshot.storage.usedBytes,
                                                          root.snapshot.storage.capacityBytes) !== null
                            from: 0
                            to: 1
                            value: {
                                const ratio = Format.formatPercent(root.snapshot.storage.usedBytes,
                                                                   root.snapshot.storage.capacityBytes);
                                return ratio === null ? 0 : ratio;
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: i18n("Sync status")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.75
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: root.stateText(root.dashboardState)
                            font.weight: Font.DemiBold
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.hasActiveTransfer("upload")

                            Kirigami.Icon {
                                source: "upload"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: root.transferSummaryText("upload")
                                elide: Text.ElideMiddle
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.hasActiveTransfer("download")

                            Kirigami.Icon {
                                source: "download"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: root.transferSummaryText("download")
                                elide: Text.ElideMiddle
                            }
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            visible: !root.hasActiveTransfer("upload") &&
                                     !root.hasActiveTransfer("download")
                            text: i18n("No active transfers")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.75
                        }
                    }
                }
            }

            DashboardSection {
                Layout.fillWidth: true
                visible: root.hasSnapshot && plasmoid.configuration.showAccountDevice
                title: i18n("Account and device")
                iconName: "user-identity"
                summary: root.snapshot.device.name
                expanded: true

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.snapshot.account.email || i18n("Account not reported")
                    elide: Text.ElideMiddle
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.snapshot.device.name
                        ? i18nc("%1 is the device name", "Device: %1", root.snapshot.device.name)
                        : i18n("Device not reported")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                    elide: Text.ElideRight
                }
            }

            DashboardSection {
                Layout.fillWidth: true
                Layout.columnSpan: 1
                title: i18n("Storage")
                iconName: "drive-harddisk"
                summary: root.storageSummaryWithPercent()
                expanded: true

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: i18n("Used")
                    }
                    PlasmaComponents.Label {
                        text: root.storageSummaryWithPercent()
                        font.weight: Font.DemiBold
                    }
                }

                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    visible: Format.formatPercent(root.snapshot.storage.usedBytes,
                                                  root.snapshot.storage.capacityBytes) !== null
                    from: 0
                    to: 1
                    value: {
                        const ratio = Format.formatPercent(root.snapshot.storage.usedBytes,
                                                           root.snapshot.storage.capacityBytes);
                        return ratio === null ? 0 : ratio;
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.snapshot.storage.unlimited
                    text: i18n("This account has unlimited storage.")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }

            DashboardSection {
                Layout.fillWidth: true
                Layout.columnSpan: 1
                title: i18n("Sync")
                iconName: "folder-sync"
                summary: root.stateText(root.dashboardState)
                expanded: true

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.snapshot.sync.rootPath || i18n("No sync folder configured")
                    elide: Text.ElideMiddle
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: root.stateText(root.dashboardState)
                    }
                    PlasmaComponents.Label {
                        text: !root.snapshot.sync.enabled ? i18n("Disabled")
                            : root.snapshot.sync.automatic === null ? i18n("Unknown")
                            : (root.snapshot.sync.automatic ? i18n("Automatic") : i18n("Manual"))
                        font: Kirigami.Theme.smallFont
                        opacity: 0.75
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: full.syncFilesText().length > 0
                    text: full.syncFilesText()
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.snapshot.sync.sizeBytes !== null
                    text: i18nc("%1 is the sync data size", "Sync data: %1",
                                Format.formatBytes(root.snapshot.sync.sizeBytes))
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }

                TransferRow {
                    Layout.fillWidth: true
                    visible: root.snapshot.sync.upload !== null
                    transfer: root.snapshot.sync.upload || ({})
                    direction: "upload"
                }
                TransferRow {
                    Layout.fillWidth: true
                    visible: root.snapshot.sync.download !== null
                    transfer: root.snapshot.sync.download || ({})
                    direction: "download"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        Layout.fillWidth: true
                        text: root.snapshot.sync.paused ? i18n("Resume sync") : i18n("Pause sync")
                        icon.name: root.snapshot.sync.paused
                            ? "media-playback-start" : "media-playback-pause"
                        enabled: root.hasSnapshot && root.snapshot.sync.configured && !root.commandBusy
                        onClicked: root.runPauseAction()
                    }
                    QQC2.Button {
                        Layout.fillWidth: true
                        text: i18n("Open sync folder")
                        icon.name: "folder-open"
                        enabled: root.snapshot.sync.rootPath.length > 0
                        onClicked: root.openSyncFolder()
                    }
                }
            }

            DashboardSection {
                Layout.fillWidth: true
                Layout.columnSpan: 1
                title: i18n("Transfers")
                iconName: "go-next"
                summary: root.detailsLoading ? i18n("Loading") : ""
                expanded: false

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.transferError.length > 0
                    text: root.transferError
                    color: Kirigami.Theme.negativeTextColor
                    wrapMode: Text.WordWrap
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.snapshot.transfers.uploads.length === 0 &&
                             root.snapshot.transfers.downloads.length === 0 &&
                             root.transferError.length === 0
                    text: root.detailsLoading ? i18n("Loading transfer information...")
                                              : i18n("No active transfers")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }

                Repeater {
                    model: root.snapshot.transfers.uploads
                    delegate: TransferRow {
                        required property var modelData
                        Layout.fillWidth: true
                        transfer: modelData
                        direction: "upload"
                    }
                }
                Repeater {
                    model: root.snapshot.transfers.downloads
                    delegate: TransferRow {
                        required property var modelData
                        Layout.fillWidth: true
                        transfer: modelData
                        direction: "download"
                    }
                }
            }

            DashboardSection {
                Layout.fillWidth: true
                Layout.columnSpan: 1
                title: i18n("Backups")
                iconName: "folder-documents"
                summary: i18nc("%1 is a folder count", "%1 folders", root.snapshot.backups.length)
                expanded: false

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.snapshot.backups.length === 0
                    text: i18n("No backup folders reported")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }

                Repeater {
                    model: root.snapshot.backups
                    delegate: PlasmaExtras.ListItem {
                        required property var modelData
                        Layout.fillWidth: true
                        separatorVisible: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: modelData.path
                                elide: Text.ElideMiddle
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: modelData.error
                                    ? i18nc("%1 backup state, %2 error", "%1 - %2",
                                            modelData.state, modelData.error.message)
                                    : modelData.fileCount === null
                                    ? modelData.state
                                    : i18nc("%1 files, %2 backup state", "%1 files - %2",
                                            Format.formatCount(modelData.fileCount), modelData.state)
                                color: modelData.error
                                    ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                font: Kirigami.Theme.smallFont
                                opacity: 0.75
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            DashboardSection {
                Layout.fillWidth: true
                Layout.columnSpan: 1
                title: i18n("Recent activity")
                iconName: "view-list-details"
                summary: root.snapshot.activity.length > 0
                    ? i18nc("%1 is an entry count", "%1 entries", root.snapshot.activity.length) : ""
                expanded: false

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.activityError.length > 0 || root.snapshot.activity.length === 0
                    text: root.activityError.length > 0 ? root.activityError
                        : root.detailsLoading ? i18n("Loading activity...") : i18n("No recent activity")
                    color: root.activityError.length > 0
                        ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
                Repeater {
                    model: root.snapshot.activity.slice(0, root.recentLimit)
                    delegate: PlasmaComponents.Label {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.message
                        elide: Text.ElideMiddle
                        font: Kirigami.Theme.smallFont
                    }
                }
            }

            DashboardSection {
                Layout.fillWidth: true
                Layout.columnSpan: full.wideLayout ? 2 : 1
                visible: root.snapshot.errors.length > 0 || root.lastError.length > 0
                title: i18n("Errors")
                iconName: "dialog-error"
                summary: root.lastError ? i18n("Needs attention") : ""
                expanded: root.lastError.length > 0

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.lastError.length > 0
                    text: root.lastError
                    color: Kirigami.Theme.negativeTextColor
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: root.snapshot.errors.slice(0, root.recentLimit)
                    delegate: PlasmaComponents.Label {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.message
                        color: Kirigami.Theme.negativeTextColor
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }

    footer: PlasmaExtras.PlasmoidHeading {
        position: PlasmaComponents.ToolBar.Footer
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.lastUpdatedText() + (root.detailError ? " - " + i18n("details unavailable") : "")
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                elide: Text.ElideRight
            }

            PlasmaComponents.BusyIndicator {
                visible: root.commandBusy
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }

            PlasmaComponents.ToolButton {
                icon.name: "internet-services"
                text: i18n("Open Jottacloud website")
                onClicked: root.openWeb()
                PlasmaComponents.ToolTip { text: i18n("Open Jottacloud website") }
            }
        }
    }
}
