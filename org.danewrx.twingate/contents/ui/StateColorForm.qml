import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols

// Active/inactive color choice.
// mode: 0 = green / red, 1 = theme colors, 2 = custom.
// Theme colors default to the theme's own positive/negative; "override" lets you pick any theme color per state.
Kirigami.FormLayout {
    property int mode: 1
    property bool themeOverride: false
    property int activeSystem: 1
    property int inactiveSystem: 2
    property alias activeColor: activeCustom.color
    property alias inactiveColor: inactiveCustom.color

    // Same order as systemColor() in main.qml.
    readonly property var systemColorNames: [i18n("Text"), i18n("Positive"), i18n("Negative"), i18n("Neutral"),
                                             i18n("Highlight"), i18n("Link"), i18n("Disabled text")]

    ColumnLayout {
        Kirigami.FormData.label: i18n("Colors:")
        Kirigami.FormData.buddyFor: themeRadio
        QQC2.RadioButton { id: themeRadio; text: i18n("Theme colors"); checked: mode === 1; onClicked: mode = 1 }
        QQC2.RadioButton { text: i18n("Green / red"); checked: mode === 0; onClicked: mode = 0 }
        QQC2.RadioButton { text: i18n("Custom"); checked: mode === 2; onClicked: mode = 2 }
    }

    QQC2.ComboBox {
        visible: mode === 1
        Kirigami.FormData.label: i18n("Theme colors:")
        model: [i18n("Theme default"), i18n("Override")]
        currentIndex: themeOverride ? 1 : 0
        onActivated: themeOverride = currentIndex === 1
    }
    QQC2.ComboBox {
        visible: mode === 1 && themeOverride
        Kirigami.FormData.label: i18n("Active color:")
        model: systemColorNames
        currentIndex: activeSystem
        onActivated: activeSystem = currentIndex
    }
    QQC2.ComboBox {
        visible: mode === 1 && themeOverride
        Kirigami.FormData.label: i18n("Inactive color:")
        model: systemColorNames
        currentIndex: inactiveSystem
        onActivated: inactiveSystem = currentIndex
    }
    ColorButton {
        id: activeCustom
        visible: mode === 2
        Kirigami.FormData.label: i18n("Active color:")
        showAlphaChannel: false
    }
    ColorButton {
        id: inactiveCustom
        visible: mode === 2
        Kirigami.FormData.label: i18n("Inactive color:")
        showAlphaChannel: false
    }
}
