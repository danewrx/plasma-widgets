import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols

KCM.SimpleKCM {
    property alias cfg_lockIcon: lockField.text
    property alias cfg_unlockIcon: unlockField.text
    property alias cfg_tintIcons: tint.checked
    property alias cfg_activeColor: activeRow.color
    property alias cfg_inactiveColor: inactiveRow.color
    property alias cfg_activeUseSystem: activeRow.system
    property alias cfg_inactiveUseSystem: inactiveRow.system

    FileDialog {
        id: picker
        property var target
        nameFilters: ["Images (*.svg *.svgz *.png *.jpg *.jpeg)"]
        onAccepted: target.text = selectedFile.toString()
    }

    component IconRow: RowLayout {
        property alias text: field.text
        QQC2.TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: i18n("Bundled icon")
        }
        QQC2.Button {
            icon.name: "document-open"
            text: i18n("Browse…")
            onClicked: { picker.target = field; picker.open() }
        }
        QQC2.Button {
            icon.name: "edit-clear"
            enabled: field.text !== ""
            onClicked: field.text = ""
            QQC2.ToolTip.text: i18n("Use bundled icon")
            QQC2.ToolTip.visible: hovered
        }
    }

    component ColorRow: RowLayout {
        property alias color: button.color
        property alias system: check.checked
        ColorButton {
            id: button
            enabled: !check.checked
            showAlphaChannel: false
        }
        QQC2.CheckBox {
            id: check
            text: i18n("Use system text color")
        }
    }

    Kirigami.FormLayout {
        IconRow { id: lockField; Kirigami.FormData.label: i18n("Lock icon (VPN on):") }
        IconRow { id: unlockField; Kirigami.FormData.label: i18n("Unlock icon (VPN off):") }
        QQC2.CheckBox {
            id: tint
            Kirigami.FormData.label: i18n("Colors:")
            text: i18n("Tint icons (turn off to keep a custom icon's own colors)")
        }
        ColorRow { id: activeRow; Kirigami.FormData.label: i18n("Active color:") }
        ColorRow { id: inactiveRow; Kirigami.FormData.label: i18n("Inactive color:") }
    }
}
