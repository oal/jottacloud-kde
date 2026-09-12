/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../code/format.mjs" as Format

ColumnLayout {
    id: row

    property var transfer: ({})
    property string direction: "upload"

    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: row.direction === "download" ? "download" : "upload"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: row.transfer.name || row.transfer.path || i18n("Unnamed file")
            elide: Text.ElideMiddle
        }

        PlasmaComponents.Label {
            text: row.transfer.progress === null
                ? row.transfer.state : Format.formatProgress(row.transfer.progress)
            opacity: 0.75
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: row.transfer.totalBytes !== null || row.transfer.rateBytesPerSecond !== null
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: row.transfer.totalBytes === null ? "" :
                `${Format.formatBytes(row.transfer.transferredBytes)} / ${Format.formatBytes(row.transfer.totalBytes)}`
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            text: Format.formatRate(row.transfer.rateBytesPerSecond)
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }

    QQC2.ProgressBar {
        Layout.fillWidth: true
        visible: row.transfer.progress !== null
        from: 0
        to: 1
        value: row.transfer.progress === null ? 0 : row.transfer.progress
    }
}
