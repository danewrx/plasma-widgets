import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// State colors for everything: tray icon, banner, status text and map pin
KCM.SimpleKCM {
    property alias cfg_colorMode: colors.mode
    property alias cfg_themeOverride: colors.themeOverride
    property alias cfg_activeSystem: colors.activeSystem
    property alias cfg_inactiveSystem: colors.inactiveSystem
    property alias cfg_activeColor: colors.activeColor
    property alias cfg_inactiveColor: colors.inactiveColor
    property bool cfg_fillBanner: false

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        StateColorForm { id: colors; Layout.fillWidth: true; twinFormLayouts: [applyForm] }
        Kirigami.FormLayout {
            id: applyForm
            Layout.fillWidth: true
            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Apply colors to:")
                model: [i18n("Accent only (icon, status text, pin)"), i18n("Whole banner")]
                currentIndex: cfg_fillBanner ? 1 : 0
                onActivated: cfg_fillBanner = currentIndex === 1
            }
        }
    }
}
