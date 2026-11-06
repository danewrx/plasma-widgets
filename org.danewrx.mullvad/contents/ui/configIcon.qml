import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_lockIcon: lockPicker.path
    property alias cfg_unlockIcon: unlockPicker.path
    property alias cfg_iconScale: scale.value
    property alias cfg_tintIcons: tintCheck.checked

    KIconThemes.IconDialog {
        id: picker
        property var target
        onAccepted: target.path = iconName
    }

    component IconPicker: ColumnLayout {
        id: pick
        property string path
        property url fallback
        spacing: 0
        Item { implicitHeight: Kirigami.Units.largeSpacing } // row padding, top and bottom so the label stays centred
        RowLayout {
            QQC2.Button {
                implicitWidth: Kirigami.Units.gridUnit * 3
                implicitHeight: implicitWidth
                onClicked: { picker.target = pick; picker.open() }
                QQC2.ToolTip.text: i18n("Choose icon…")
                QQC2.ToolTip.visible: hovered
                contentItem: IconView {
                    value: pick.path
                    fallback: pick.fallback
                    tint: tintCheck.checked
                    tintColor: Kirigami.Theme.textColor
                }
            }
            QQC2.Button {
                icon.name: "edit-clear"
                visible: pick.path !== ""
                onClicked: pick.path = ""
                QQC2.ToolTip.text: i18n("Use bundled icon")
                QQC2.ToolTip.visible: hovered
            }
        }
        Item { implicitHeight: Kirigami.Units.largeSpacing }
    }

    Kirigami.FormLayout {
        IconPicker { id: lockPicker; Kirigami.FormData.label: i18n("Lock icon (VPN on):"); fallback: Qt.resolvedUrl("../icons/lock.svg") }
        IconPicker { id: unlockPicker; Kirigami.FormData.label: i18n("Unlock icon (VPN off):"); fallback: Qt.resolvedUrl("../icons/unlock.svg") }
        QQC2.SpinBox {
            id: scale
            Kirigami.FormData.label: i18n("Scale (%):")
            from: 10; to: 200; stepSize: 5
        }
        QQC2.CheckBox {
            id: tintCheck
            Kirigami.FormData.label: i18n("Tint:")
            text: i18n("Tint icons with the state color (turn off to keep a custom icon's own colors)")
        }
    }
}
