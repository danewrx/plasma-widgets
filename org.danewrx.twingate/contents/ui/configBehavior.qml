import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// What clicking the panel icon does
KCM.SimpleKCM {
    property alias cfg_clickAction: action.currentIndex
    property alias cfg_middleClick: middle.checked

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: action
            Kirigami.FormData.label: i18n("Left-click:")
            model: [i18n("Open the popup"), i18n("Connect / disconnect")]
        }
        QQC2.CheckBox {
            id: middle
            Kirigami.FormData.label: i18n("Middle-click:")
            text: i18n("Enabled")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.Wrap
            opacity: 0.7
            text: !middle.checked ? i18n("Middle-click does nothing.")
                : action.currentIndex === 0 ? i18n("Middle-click connects or disconnects.")
                : i18n("Middle-click opens the popup.")
        }
    }
}
