/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "../code/status.mjs" as Status

MouseArea {
    id: compact

    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property int iconSize: Kirigami.Units.iconSizes.smallMedium
    readonly property int compactSize: iconSize + Kirigami.Units.smallSpacing * 2
    readonly property int summaryWidth: preferredSummaryWidth()
    readonly property bool summaryRequested: root.compactStorageEnabled || root.compactTransfersEnabled
    readonly property bool showSummary: horizontal && summaryRequested && width >= summaryWidth
    readonly property bool showStorage: showSummary && root.compactStorageEnabled &&
                                       (root.compactStorageDisplayText().length > 0 ||
                                        root.compactStorageDetailsEnabled)
    readonly property bool showStorageDetails: showStorage && root.compactStorageDetailsEnabled
    readonly property bool showTransfers: showSummary && root.compactTransfersEnabled &&
                                         (root.hasActiveTransfer("upload") ||
                                          root.hasActiveTransfer("download"))
    readonly property color badgeColor: {
        switch (root.stateColor(root.dashboardState)) {
        case "positive": return Kirigami.Theme.positiveTextColor;
        case "neutral": return Kirigami.Theme.neutralTextColor;
        case "negative": return Kirigami.Theme.negativeTextColor;
        default: return Kirigami.Theme.disabledTextColor;
        }
    }

    function preferredSummaryWidth() {
        let width = compactSize;
        const storageText = root.compactStorageDisplayText();
        if (root.compactStorageEnabled && (storageText.length > 0 ||
                                           root.compactStorageDetailsEnabled)) {
            const storageWidth = root.compactStorageDetailsEnabled
                ? Math.max(storageMetrics.width, stateMetrics.width)
                : percentageMetrics.width;
            width += Kirigami.Units.smallSpacing +
                storageWidth;
        }
        if (root.compactTransfersEnabled) {
            const transferCount = (root.hasActiveTransfer("upload") ? 1 : 0) +
                (root.hasActiveTransfer("download") ? 1 : 0);
            if (transferCount > 0)
                width += Kirigami.Units.smallSpacing + transferCount * iconSize;
        }
        return width;
    }

    Layout.minimumWidth: horizontal ? compactSize : 0
    Layout.preferredWidth: horizontal && summaryRequested ? summaryWidth : compactSize
    Layout.minimumHeight: horizontal ? 0 : compactSize
    Layout.preferredHeight: compactSize

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Jottacloud status")
    Accessible.description: root.tooltipText() + " - " + root.storageSummary()

    onClicked: (mouse) => {
        if (mouse.button === Qt.MiddleButton)
            root.refresh();
        else
            root.expanded = !root.expanded;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.expanded = !root.expanded;
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            id: iconHolder
            Layout.preferredWidth: compact.iconSize + Kirigami.Units.smallSpacing
            Layout.preferredHeight: compact.iconSize + Kirigami.Units.smallSpacing
            Layout.alignment: compact.showSummary ? Qt.AlignVCenter : Qt.AlignCenter

            Kirigami.Icon {
                id: cloudIcon
                anchors.centerIn: parent
                source: root.brandIconSource
                implicitWidth: compact.iconSize
                implicitHeight: implicitWidth
                opacity: root.dashboardState === Status.STATE.UNKNOWN ? 0.65 : 1
            }

            Rectangle {
                id: badge
                anchors.right: cloudIcon.right
                anchors.bottom: cloudIcon.bottom
                anchors.rightMargin: -width * 0.1
                anchors.bottomMargin: -height * 0.1
                width: Math.max(Kirigami.Units.smallSpacing * 2,
                                symbol.implicitWidth + 4, symbol.implicitHeight + 4)
                height: width
                radius: width / 2
                color: Kirigami.Theme.backgroundColor
                border.color: compact.badgeColor
                border.width: 1

                Text {
                    id: symbol
                    anchors.fill: parent
                    text: root.stateSymbol(root.dashboardState)
                    color: compact.badgeColor
                    font.pixelSize: Math.max(6, Kirigami.Theme.smallFont.pixelSize - 2)
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        ColumnLayout {
            visible: compact.showStorage
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.compactStorageDisplayText()
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.stateText(root.dashboardState)
                font: Kirigami.Theme.smallFont
                visible: compact.showStorageDetails
                opacity: 0.75
                elide: Text.ElideRight
            }
        }

        RowLayout {
            visible: compact.showTransfers
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Kirigami.Icon {
                visible: root.hasActiveTransfer("upload")
                source: "upload"
                implicitWidth: compact.iconSize
                implicitHeight: implicitWidth
                Accessible.name: i18n("Uploading")
            }

            Kirigami.Icon {
                visible: root.hasActiveTransfer("download")
                source: "download"
                implicitWidth: compact.iconSize
                implicitHeight: implicitWidth
                Accessible.name: i18n("Downloading")
            }
        }
    }

    TextMetrics {
        id: storageMetrics
        text: root.compactStorageText()
        font: Kirigami.Theme.defaultFont
    }

    TextMetrics {
        id: stateMetrics
        text: root.stateText(root.dashboardState)
        font: Kirigami.Theme.smallFont
    }

    TextMetrics {
        id: percentageMetrics
        text: root.storagePercentageText()
        font: Kirigami.Theme.defaultFont
    }
}
