import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Icon size and the colors for connected / not connected
KCM.SimpleKCM {
    property alias cfg_colorMode: colors.mode
    property alias cfg_themeOverride: colors.themeOverride
    property alias cfg_activeSystem: colors.activeSystem
    property alias cfg_inactiveSystem: colors.inactiveSystem
    property alias cfg_activeColor: colors.activeColor
    property alias cfg_inactiveColor: colors.inactiveColor
    property alias cfg_iconScale: scale.value

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        StateColorForm { id: colors; Layout.fillWidth: true; twinFormLayouts: [sizeForm] }
        Kirigami.FormLayout {
            id: sizeForm
            Layout.fillWidth: true
            QQC2.SpinBox {
                id: scale
                Kirigami.FormData.label: i18n("Icon scale (%):")
                from: 10; to: 200; stepSize: 5
            }
        }
    }
}
