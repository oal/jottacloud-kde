/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: section

    property string title: ""
    property string summary: ""
    property string iconName: ""
    property bool expanded: true
    default property alias sectionContent: body.data

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        id: heading
        Layout.fillWidth: true
        implicitHeight: Math.max(Kirigami.Units.gridUnit * 2.2,
                                 headingRow.implicitHeight + Kirigami.Units.smallSpacing * 2)
        color: headingMouse.containsMouse ? Kirigami.Theme.highlightColor : "transparent"
        radius: Kirigami.Units.smallSpacing

        RowLayout {
            id: headingRow
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: section.iconName
                visible: source !== ""
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: section.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                Layout.maximumWidth: parent.width * 0.45
                text: section.summary
                visible: text.length > 0 && !section.expanded
                opacity: 0.7
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }

            Kirigami.Icon {
                source: section.expanded ? "arrow-up" : "arrow-down"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                opacity: 0.7
            }
        }

        MouseArea {
            id: headingMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.name: section.title
            onClicked: section.expanded = !section.expanded
        }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        visible: section.expanded
        spacing: Kirigami.Units.smallSpacing
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }
}
