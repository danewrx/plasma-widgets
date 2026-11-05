import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Click toggles connect/disconnect, tooltip shows `mullvad status`.
// shortcut: polls the CLI every 5 s and has no location picker, add one if you want it.
PlasmoidItem {
    id: root

    property string vpnState: "unknown"   // connected | connecting | disconnected | blocked | unknown
    property string detail: ""
    property string lastError: ""

    toolTipMainText: "Mullvad: " + vpnState
    toolTipSubText: detail || lastError

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source !== "mullvad status") { refresh(); return }
            const out = (data["stdout"] || "").trim()
            root.lastError = (data["stderr"] || "exit " + data["exit code"]).toString().trim()
            const head = out.split("\n")[0].toLowerCase()
            root.vpnState = head.startsWith("connected") ? "connected"
                          : head.startsWith("connecting") ? "connecting"
                          : head.startsWith("disconnected") ? "disconnected"
                          : head.startsWith("blocked") ? "blocked" : "unknown"
            root.detail = out.split("\n").slice(1).map(l => l.trim()).join("\n")
        }
    }

    function refresh() { exec.connectSource("mullvad status") }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }


    fullRepresentation: Text {
        text: root.vpnState + "\n" + root.detail
        color: Kirigami.Theme.textColor
    }

    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

        IconView {
            id: icon
            readonly property var cfg: Plasmoid.configuration
            readonly property bool on: root.vpnState === "connected" || root.vpnState === "connecting"
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * cfg.iconScale / 100 // 100% = the full slot
            height: width
            value: on ? cfg.lockIcon : cfg.unlockIcon
            fallback: Qt.resolvedUrl("../icons/" + (on ? "lock" : "unlock") + ".svg")
            opacity: root.vpnState === "connecting" ? 0.5 : 1.0
            tint: cfg.tintIcons
            // Same order as the list in configAppearance.qml.
            function system(i) {
                return [Kirigami.Theme.textColor, Kirigami.Theme.positiveTextColor, Kirigami.Theme.negativeTextColor,
                        Kirigami.Theme.neutralTextColor, Kirigami.Theme.highlightColor, Kirigami.Theme.linkColor,
                        Kirigami.Theme.disabledTextColor][i]
            }
            tintColor: cfg.colorMode === 0 ? (on ? "#1f8a3b" : "#da4453")
                     : cfg.colorMode === 1 ? system(on ? cfg.activeSystem : cfg.inactiveSystem)
                     : (on ? cfg.activeColor : cfg.inactiveColor)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: exec.connectSource(root.vpnState === "connected" || root.vpnState === "connecting"
                                          ? "mullvad disconnect" : "mullvad connect")
        }
    }
}
