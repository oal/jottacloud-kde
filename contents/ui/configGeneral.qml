/* SPDX-License-Identifier: MPL-2.0 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_cliExecutable: cliExecutable.text
    property alias cfg_refreshIntervalSeconds: refreshInterval.value
    property alias cfg_showAccountDevice: showAccountDevice.checked
    property alias cfg_compactDisplayMode: compactDisplayMode.currentIndex
    property alias cfg_showCompactTransfers: showCompactTransfers.checked
    property alias cfg_recentEntries: recentEntries.value
    property alias cfg_notificationsEnabled: notificationsEnabled.checked

    Kirigami.FormLayout {
        anchors.fill: parent

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Command line client")
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: cliExecutable
            Kirigami.FormData.label: i18n("CLI executable:")
            placeholderText: i18n("jotta-cli")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            selectByMouse: true
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: i18n("Use jotta-cli when it is on Plasma's PATH. You can also enter an absolute path to a host wrapper. The widget never stores or asks for your login token.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            opacity: 0.75
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Updates")
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: refreshInterval
            Kirigami.FormData.label: i18n("Refresh every:")
            from: 10
            to: 600
            stepSize: 10
            textFromValue: (value) => i18np("%1 second", "%1 seconds", value)
            valueFromText: (text) => parseInt(text, 10)
        }

        QQC2.SpinBox {
            id: recentEntries
            Kirigami.FormData.label: i18n("Recent entries:")
            from: 1
            to: 20
            textFromValue: (value) => i18np("%1 entry", "%1 entries", value)
            valueFromText: (text) => parseInt(text, 10)
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Dashboard")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showAccountDevice
            Kirigami.FormData.label: i18n("Account section:")
            text: i18n("Show account and device information")
        }

        QQC2.ComboBox {
            id: compactDisplayMode
            Kirigami.FormData.label: i18n("Panel storage:")
            model: [
                i18n("Logo only"),
                i18n("Logo + percentage"),
                i18n("Percentage + size + status")
            ]
        }

        QQC2.CheckBox {
            id: showCompactTransfers
            Kirigami.FormData.label: i18n("Panel transfers:")
            text: i18n("Show upload and download indicators while active")
        }

        QQC2.CheckBox {
            id: notificationsEnabled
            Kirigami.FormData.label: i18n("Error notifications:")
            text: i18n("Notify when the CLI or sync enters an error state")
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: i18n("Normal upload and download progress never creates a notification. Repeated copies of the same error are suppressed.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            opacity: 0.75
        }

    }
}
