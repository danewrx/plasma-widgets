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
    property string host: ""           // e.g. daneb.us1.twingate.com, from admin_url
    property string pending: ""        // "start" | "stop" while a toggle is in flight
    property double pendingSince: 0
    property string lastError: ""

    readonly property bool online: link === "online"
    readonly property string title: link === "online" ? i18n("Connected (Enabled)")
                                  : link === "stopped" ? i18n("Disconnected (Disabled)")
                                  : link === "offline" ? i18n("Disconnected")
                                  : link === "missing" ? i18n("Twingate CLI not found")
                                  : statusText || i18n("Unknown")
    readonly property var cfg: Plasmoid.configuration
    // Order matches StateColorForm.qml.
    function systemColor(i) {
        return [Kirigami.Theme.textColor, Kirigami.Theme.positiveTextColor, Kirigami.Theme.negativeTextColor,
                Kirigami.Theme.neutralTextColor, Kirigami.Theme.highlightColor, Kirigami.Theme.linkColor,
                Kirigami.Theme.disabledTextColor][i]
    }
    // Unknown / missing is neither on nor off, so it stays grey whatever the mode.
    readonly property color stateColor: {
        if (link !== "online" && link !== "stopped" && link !== "offline") return Kirigami.Theme.disabledTextColor
        const on = online
        return cfg.colorMode === 0 ? (on ? "#1f8a3b" : "#da4453")
             : cfg.colorMode === 1 ? systemColor(cfg.themeOverride ? (on ? cfg.activeSystem : cfg.inactiveSystem) : (on ? 1 : 2))
             : (on ? cfg.activeColor : cfg.inactiveColor)
    }

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
                else { root.items = []; root.networkName = ""; root.host = "" }
            } else if (source === "twingate-notifier resources") {
                try {
                    const j = JSON.parse(out)
                    root.items = j.resources || []
                    root.networkName = j.network_name || ""
                    root.host = (j.admin_url || "").replace(/^https?:\/\//, "")
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
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        spacing: 0

        // ---- header: logo mark + wordmark, state pill, switch ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: header.implicitHeight + Kirigami.Units.largeSpacing * 2
            color: Kirigami.Theme.alternateBackgroundColor
            Rectangle { // edge line
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
            }
            RowLayout {
                id: header
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Kirigami.Units.largeSpacing }
                spacing: Kirigami.Units.largeSpacing
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    IconView { // wordmark: follows the theme text color (white on dark, black on light), not the state
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredWidth: Layout.preferredHeight * 748 / 166
                        value: Qt.resolvedUrl("../icons/twingate-wordmark.png").toString()
                        tintColor: Kirigami.Theme.textColor
                    }
                    Rectangle { // state pill
                        implicitWidth: pill.implicitWidth + Kirigami.Units.largeSpacing * 2
                        implicitHeight: pill.implicitHeight + Kirigami.Units.smallSpacing
                        radius: height / 2
                        color: Qt.alpha(root.stateColor, 0.18)
                        RowLayout {
                            id: pill
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            Rectangle { width: Kirigami.Units.smallSpacing * 2; height: width; radius: width / 2; color: root.stateColor }
                            QQC2.Label {
                                text: root.pending ? i18n("Working…") : root.title
                                color: root.stateColor
                                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                                font.bold: true
                            }
                        }
                    }
                    QQC2.Label {
                        visible: root.online && root.host !== ""
                        Layout.fillWidth: true
                        text: (root.networkName ? root.networkName + " · " : "") + root.host
                        opacity: 0.65
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
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
        }
        QQC2.Label {
            visible: text !== ""
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            text: root.lastError
            wrapMode: Text.Wrap
            color: Kirigami.Theme.negativeTextColor
        }

        Kirigami.PlaceholderMessage {
            visible: !root.online
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing
            icon.name: "network-vpn-disconnected"
            icon.color: root.stateColor
            text: root.link === "missing" ? i18n("Install the Twingate client")
                : root.link === "unknown" ? i18n("Couldn't read the status")
                : i18n("Twingate is off")
            explanation: root.link === "missing" ? i18n("This widget needs the twingate command-line tool.")
                       : root.link === "unknown" ? root.statusText
                       : i18n("Use the switch to connect. If it asks you to sign in, run “twingate auth” in a terminal.")
        }

        // ---- resources ----
        QQC2.Label {
            visible: root.online
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18n("RESOURCES") + "  " + root.items.length
            opacity: 0.6
            font.bold: true
            font.letterSpacing: 1
            font.pixelSize: Kirigami.Units.gridUnit * 0.7
        }
        ListView {
            visible: root.online
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.smallSpacing
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: root.items
            delegate: QQC2.ItemDelegate {
                id: card
                width: ListView.view.width
                text: modelData.name // for accessibility; the content is drawn below
                readonly property bool openable: modelData.can_open_in_browser && !!modelData.open_url
                onClicked: if (openable) Qt.openUrlExternally(modelData.open_url)
                background: Rectangle {
                    radius: Kirigami.Units.cornerRadius
                    color: card.hovered && card.openable ? Qt.alpha(root.stateColor, 0.14) : Qt.alpha(Kirigami.Theme.textColor, 0.06)
                    border.width: 1
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
                }
                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Rectangle { // icon tile
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                        radius: Kirigami.Units.cornerRadius
                        color: Qt.alpha(root.stateColor, 0.18)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: card.openable ? "internet-services" : "network-server"
                            isMask: true
                            color: root.stateColor
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.Label { text: modelData.name; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        QQC2.Label {
                            text: modelData.alias || modelData.address
                            opacity: 0.65
                            font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Kirigami.Icon { // "opens in the browser" hint
                        visible: card.openable
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: "go-next"
                        isMask: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.5
                    }
                }
            }
        }
    }

    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        IconView {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * root.cfg.iconScale / 100 // 100% = the full slot
            height: width
            value: Qt.resolvedUrl("../icons/twingate.svg").toString()
            tintColor: root.stateColor
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
