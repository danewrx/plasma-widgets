import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: view
    property string value
    property url fallback
    property bool tint: true
    property color tintColor: "white"
    readonly property bool isName: value !== "" && value.indexOf("/") < 0

    layer.enabled: tint
    layer.effect: MultiEffect {
        brightness: 1.0 // colorization keeps luminance, so dark art must be lifted to white first
        colorization: 1.0
        colorizationColor: view.tintColor
    }

    Kirigami.Icon {
        anchors.fill: parent
        visible: view.isName
        source: view.isName ? view.value : ""
    }
    // Plain Image for files: Kirigami.Icon swapped file icons for theme ones after the first frame.
    Image {
        anchors.fill: parent
        visible: !view.isName
        source: view.isName ? "" : view.value.startsWith("/") ? "file://" + view.value : (view.value || view.fallback)
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
    }
}
