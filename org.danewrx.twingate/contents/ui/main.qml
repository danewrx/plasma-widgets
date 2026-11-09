import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string link:  "unknown"   // online | offline | stopped | missing | unknown
    property string statusText: ""     // first line of `twingate status`, e.g. "Online: User"
    property var items:     []         // from `twingate-notifier resources` (JSON), only while online
    property string networkName: ""
    property string pending: ""        // "start" | "stop" while a toggle is in flight
    property double pendingSince: 0
    property string lastError: ""

    readonly property bool online: link === "online"
    readonly property string title: link === "online" ? i18n("Connected")
                                  : link === "stopped" ? i18n("Not running")
                                  : link === "offline" ? i18n("Offline")
                                  : link === "missing" ? i18n("Twingate CLI not found")
                                  : statusText || i18n("Unknown")
    readonly property color stateColor: online ? Kirigami.Theme.positiveTextColor
                                      : link === "stopped" || link === "offline" ? Kirigami.Theme.negativeTextColor
                                      : Kirigami.Theme.disabledTextColor

    toolTipMainText: "Twingate — " + title
    toolTipSubText: online && networkName ? networkName : ""

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: root.online ? i18n("Disconnect") : i18n("Connect")
            icon.name: root.online ? "network-disconnect" : "network-connect"
            enabled: root.link !== "missing"
            onTriggered: root.setOnline(!root.online)
        }
    ]

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            const out = (data["stdout"] || "").trim()
            const code = data["exit code"]
            if (source === "twingate status") {
                root.lastError = ""
                const head = out.split("\n")[0], low = head.toLowerCase()
                let st = code === 127 ? "missing"
                       : low.startsWith("online") ? "online"
                       : low.startsWith("not-running") ? "stopped"
                       : low.startsWith("offline") ? "offline" : "unknown"
                if (root.pending) {
                    const caughtUp = root.pending === "start" ? st === "online" : st === "stopped"
                    // pkexec cancelled or failed: give up after a while and show the real state
                    if (caughtUp || Date.now() - root.pendingSince > 15000) root.pending = ""
                    else st = root.link
                }
                root.link = st
                root.statusText = head
                if (st === "online") root.refreshResources()
                else { root.items = []; root.networkName = "" }
            } else if (source === "twingate-notifier resources") {
                try {
                    const j = JSON.parse(out)
                    root.items = j.resources || []
                    root.networkName = j.network_name || ""
                } catch (e) { /* the daemon answers plain text ("Offline") while not connected */ }
            } else {
                // a toggle finished; pkexec exits 126/127 when the prompt was dismissed
                if (code) { root.pending = ""; root.lastError = (data["stderr"] || "").toString().trim().split("\n")[0] }
                refresh()
            }
        }
    }

    function refresh() { exec.connectSource("twingate status") }
    function refreshResources() { exec.connectSource("twingate-notifier resources") }
    // `twingate start/stop` just run `sudo systemctl`, which cannot prompt from here; pkexec shows a KDE dialog instead.
    function setOnline(on) {
        pending = on ? "start" : "stop"
        pendingSince = Date.now()
        link = on ? "offline" : link
        exec.connectSource("pkexec systemctl " + pending + " twingate")
    }

    Timer {
        interval: root.pending ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 20
        spacing: 0

        RowLayout {
            Layout.margins: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: root.online ? "network-vpn" : "network-vpn-disconnected"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                isMask: true
                color: root.linkColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                QQC2.Label { text: "Twingate"; font.bold: true }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.pending ? i18n("Working…") : root.title + (root.online && root.networkName ? " · " + root.networkName : "")
                    color: root.linkColor
                    elide: Text.ElideRight
                }
            }
            QQC2.Switch {
                enabled: root.link !== "missing" && !root.pending
                checked: root.online
                onToggled: {
                    root.setOnline(checked)
                    checked = Qt.binding(() => root.online) // a click breaks the binding otherwise
                }
            }
        }
        QQC2.Label {
            visible: text !== ""
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            text: root.lastError
            wrapMode: Text.Wrap
            color: Kirigami.Theme.negativeTextColor
        }
        Kirigami.Separator { Layout.fillWidth: true }

        Kirigami.PlaceholderMessage {
            visible: !root.online
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing
            icon.name: "network-vpn-disconnected"
            text: root.link === "missing" ? i18n("Install the Twingate client")
                : root.link === "unknown" ? i18n("Couldn't read the status")
                : i18n("Twingate is off")
            explanation: root.link === "missing" ? i18n("This widget needs the twingate command-line tool.")
                       : root.link === "unknown" ? root.statusText
                       : i18n("Use the switch to connect. If it asks you to sign in, run “twingate auth” in a terminal.")
        }

        QQC2.ScrollView {
            visible: root.online
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                clip: true
                model: root.items
                delegate: QQC2.ItemDelegate {
                    width: ListView.view.width
                    text: modelData.name
                    // address is the loopback placeholder for alias-backed resources, so prefer the alias
                    icon.name: modelData.can_open_in_browser ? "internet-services" : "network-server"
                    onClicked: if (modelData.can_open_in_browser && modelData.open_url) Qt.openUrlExternally(modelData.open_url)
                    contentItem: ColumnLayout {
                        spacing: 0
                        QQC2.Label { text: modelData.name; elide: Text.ElideRight; Layout.fillWidth: true }
                        QQC2.Label {
                            text: modelData.alias || modelData.address
                            opacity: 0.7
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Kirigami.Icon {
            anchors.fill: parent
            source: root.online ? "network-vpn" : "network-vpn-disconnected"
            isMask: true
            color: root.linkColor
            opacity: root.pending ? 0.5 : 1
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) root.setOnline(!root.online)
                else root.expanded = !root.expanded
            }
        }
    }
}
