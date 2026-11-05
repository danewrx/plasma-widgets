import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols

KCM.SimpleKCM {
    property alias cfg_lockIcon: lockPicker.path
    property alias cfg_unlockIcon: unlockPicker.path
    property alias cfg_iconScale: scale.value
    property alias cfg_tintIcons: tintCheck.checked
    property alias cfg_activeColor: activeCustom.color
    property alias cfg_inactiveColor: inactiveCustom.color
    property alias cfg_colorMode: modeBox.currentIndex
    property alias cfg_activeSystem: activeSystemBox.currentIndex
    property alias cfg_inactiveSystem: inactiveSystemBox.currentIndex

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

    readonly property var systemColorNames: [i18n("Text"), i18n("Positive (green)"), i18n("Negative (red)"),
                                             i18n("Neutral (orange)"), i18n("Highlight"), i18n("Link"), i18n("Disabled text")]

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { text: i18n("Icons"); level: 2 }
        Kirigami.Separator { Layout.fillWidth: true }
        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            twinFormLayouts: [colorsForm]
            IconPicker { id: lockPicker; Kirigami.FormData.label: i18n("Lock icon (VPN on):"); fallback: Qt.resolvedUrl("../icons/lock.svg") }
            IconPicker { id: unlockPicker; Kirigami.FormData.label: i18n("Unlock icon (VPN off):"); fallback: Qt.resolvedUrl("../icons/unlock.svg") }
            QQC2.SpinBox {
                id: scale
                Kirigami.FormData.label: i18n("Scale (%):")
                from: 10; to: 200; stepSize: 5
            }
        }

        Kirigami.Heading { text: i18n("Colors"); level: 2; Layout.topMargin: Kirigami.Units.gridUnit }
        Kirigami.Separator { Layout.fillWidth: true }
        Kirigami.FormLayout {
            id: colorsForm
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            QQC2.CheckBox {
                id: tintCheck
                text: i18n("Tint icons (turn off to keep a custom icon's own colors)")
            }
            QQC2.ComboBox {
                id: modeBox
                Kirigami.FormData.label: i18n("Colors:")
                model: [i18n("Default (green / red)"), i18n("System colors"), i18n("Custom colors")]
            }
            QQC2.ComboBox {
                id: activeSystemBox
                visible: modeBox.currentIndex === 1
                Kirigami.FormData.label: i18n("Active color:")
                model: systemColorNames
            }
            QQC2.ComboBox {
                id: inactiveSystemBox
                visible: modeBox.currentIndex === 1
                Kirigami.FormData.label: i18n("Inactive color:")
                model: systemColorNames
            }
            ColorButton {
                id: activeCustom
                visible: modeBox.currentIndex === 2
                Kirigami.FormData.label: i18n("Active color:")
                showAlphaChannel: false
            }
            ColorButton {
                id: inactiveCustom
                visible: modeBox.currentIndex === 2
                Kirigami.FormData.label: i18n("Inactive color:")
                showAlphaChannel: false
            }
        }
    }
}
