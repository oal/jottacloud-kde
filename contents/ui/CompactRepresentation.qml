/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "../code/status.mjs" as Status

MouseArea {
    id: compact

    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property color badgeColor: {
        switch (root.stateColor(root.dashboardState)) {
        case "positive": return Kirigami.Theme.positiveTextColor;
        case "neutral": return Kirigami.Theme.neutralTextColor;
        case "negative": return Kirigami.Theme.negativeTextColor;
        default: return Kirigami.Theme.disabledTextColor;
        }
    }

    Layout.minimumWidth: horizontal ? Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2 : 0
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: horizontal ? 0 : Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: Layout.minimumHeight

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.toolTipMainText
    Accessible.description: root.tooltipText()

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

    Kirigami.Icon {
        id: cloudIcon
        anchors.centerIn: parent
        source: root.stateIcon(root.dashboardState)
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: implicitWidth
        color: Kirigami.Theme.textColor
        opacity: root.dashboardState === Status.STATE.UNKNOWN ? 0.65 : 1
    }

    Rectangle {
        id: badge
        anchors.right: cloudIcon.right
        anchors.bottom: cloudIcon.bottom
        anchors.rightMargin: -width * 0.25
        anchors.bottomMargin: -height * 0.2
        width: Math.max(Kirigami.Units.gridUnit * 0.75, symbol.implicitWidth + 4)
        height: Math.max(Kirigami.Units.gridUnit * 0.65, symbol.implicitHeight + 2)
        radius: height / 2
        color: Kirigami.Theme.backgroundColor
        border.color: compact.badgeColor
        border.width: 1

        Text {
            id: symbol
            anchors.centerIn: parent
            text: root.stateSymbol(root.dashboardState)
            color: compact.badgeColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.weight: Font.Bold
        }
    }

    QQC2.ToolTip.visible: compact.containsMouse
    QQC2.ToolTip.text: root.tooltipText()
}
