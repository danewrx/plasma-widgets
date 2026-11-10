import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string link:  "unknown"   // online | auth | offline | stopped | missing | unknown
    property string authUrl: ""        // sign-in page from `twingate status -v` while link is "auth"
    property string statusText: ""     // first line of `twingate status`, e.g. "Online: User"
    property var items:     []         // from `twingate-notifier resources` (JSON), only while online
    property string networkName: ""
    property string host: ""
    property double upSince: 0
    property double nowMs: Date.now()
    readonly property string uptimeText: {
        if (!upSince) return ""
        const t = Math.max(0, Math.floor((nowMs - upSince) / 1000)), d = Math.floor(t / 86400)
        const p = n => String(n).padStart(2, "0")
        return (d ? d + "d " : "") + p(Math.floor(t % 86400 / 3600)) + ":" + p(Math.floor(t % 3600 / 60)) + ":" + p(t % 60)
    }
    property string pending: ""        // "start" | "stop" while a toggle is in flight
    property double pendingSince: 0
    property string lastError: ""

    readonly property bool online: link === "online"
    readonly property bool active: link === "online" || link === "auth" // the service is running (signed in or waiting for sign-in)
    readonly property string title: link === "online" ? i18n("Connected (Enabled)")
                                  : link === "auth" ? i18n("Sign-in required")
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
        if (link === "auth") return Kirigami.Theme.neutralTextColor // waiting on you, neither on nor off
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
            text: root.active ? i18n("Disconnect") : i18n("Connect")
            icon.name: root.active ? "network-disconnect" : "network-connect"
            enabled: root.link !== "missing"
            onTriggered: root.setOnline(!root.active)
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
            if (source === root.statusCmd) {
                root.lastError = ""
                const head = out.split("\n")[0], low = head.toLowerCase()
                let st = code === 127 ? "missing"
                       : low.startsWith("online") ? "online"
                       : low.startsWith("authenticating") ? "auth"
                       : low.startsWith("not-running") ? "stopped"
                       : low.startsWith("offline") ? "offline" : "unknown"
                if (root.pending) {
                    const caughtUp = root.pending === "start" ? (st === "online" || st === "auth") : st === "stopped"
                    // pkexec cancelled or failed: give up after a while and show the real state
                    if (caughtUp || Date.now() - root.pendingSince > 15000) root.pending = ""
                    else st = root.link
                }
                // Only ever open a twingate.com sign-in page, whatever the CLI prints.
                const url = out.match(/https:\/\/[a-z0-9.-]+\.twingate\.com\/\S*/i)
                root.authUrl = st === "auth" && url ? url[0] : ""
                root.link = st
                root.statusText = head
                if (st === "online" && !root.upSince) exec.connectSource(root.upCmd)
                if (st !== "online") root.upSince = 0
                if (st === "online") root.refreshResources()
                else { root.items = []; root.networkName = ""; root.host = "" }
            } else if (source === "twingate-notifier resources") {
                try {
                    const j = JSON.parse(out)
                    root.items = j.resources || []
                    root.networkName = j.network_name || ""
                    root.host = (j.admin_url || "").replace(/^https?:\/\//, "")
                } catch (e) { /* the daemon answers plain text ("Offline") while not connected */ }
            } else if (source === root.upCmd) {
                root.upSince = (parseInt(out) || 0) * 1000
            } else {
                // a toggle finished; pkexec exits 126/127 when the prompt was dismissed
                if (code) { root.pending = ""; root.lastError = (data["stderr"] || "").toString().trim().split("\n")[0] }
                refresh()
            }
        }
    }

    readonly property string upCmd: "date -d \"$(systemctl show twingate -p ActiveEnterTimestamp --value)\" +%s"
    // ---- favicons: a resource's own icon, found through the tunnel ----
    property var icons: ({})           // open_url -> icon url ("" = the page has none, use the default icon)
    property var iconBusy: ({})        // open_url -> true while a request is in flight
    function resolveUrl(base, href) {
        const m = base.match(/^([a-z]+:\/\/[^\/?#]+)([^?#]*)/i)
        if (!m) return ""
        const path = m[2] || "/"
        const url = /^[a-z][a-z0-9+.-]*:/i.test(href) ? href
                  : href.startsWith("//") ? base.split(":")[0] + ":" + href
                  : href.startsWith("/") ? m[1] + href
                  : m[1] + path.slice(0, path.lastIndexOf("/") + 1) + href
        return /^https?:\/\//i.test(url) ? url : ""
    }
    function fetchIcon(url) {
        if (!/^https?:\/\//i.test(url) || url in icons || iconBusy[url]) return
        iconBusy[url] = true
        const xhr = new XMLHttpRequest()
        xhr.timeout = 5000
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            delete iconBusy[url]
            if (xhr.status === 0) return
            let icon = ""
            for (const tag of (xhr.status === 200 ? xhr.responseText.match(/<link\b[^>]*>/gi) : null) || []) {
                const rel = tag.match(/\brel\s*=\s*["']([^"']*)["']/i), href = tag.match(/\bhref\s*=\s*["']([^"']*)["']/i)
                if (rel && href && rel[1].toLowerCase().split(/\s+/).includes("icon")) { icon = resolveUrl(url, href[1]); break }
            }
            if (!icon) icon = resolveUrl(url, "/favicon.ico")
            const next = {}
            for (const k in icons) next[k] = icons[k]
            next[url] = icon
            icons = next
        }
        xhr.open("GET", url)
        xhr.send()
    }
    readonly property string statusCmd: "twingate status -v"
    function refresh() { exec.connectSource(statusCmd) }
    function refreshResources() { exec.connectSource("twingate-notifier resources") }
    // `twingate start/stop` just run `sudo systemctl`, which cannot prompt from here; pkexec shows a KDE dialog instead.
    function setOnline(on) {
        pending = on ? "start" : "stop"
        pendingSince = Date.now()
        link = on ? "offline" : link
        exec.connectSource("pkexec systemctl " + pending + " twingate")
    }

    Timer {
        interval: 1000
        running: root.expanded && root.online
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }
    Timer {
        interval: root.pending ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Plain Item root with the preferred size on it, like the mullvad widget: Plasma sized the popup from the layout's
    // natural height when the root was the ColumnLayout itself, so the height kept shrinking.
    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 26
        Kirigami.Action {
            id: signInAction
            text: i18n("Open sign-in page")
            icon.name: "internet-services"
            onTriggered: Qt.openUrlExternally(root.authUrl)
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: banner
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                clip: true
                implicitHeight: bannerContent.implicitHeight + Kirigami.Units.gridUnit * 1.8
                color: Kirigami.Theme.alternateBackgroundColor
                Rectangle { // edge line
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
                }
                Item {
                    anchors.fill: parent
                    Repeater {
                        model: 3
                        Rectangle {
                            id: blob
                            readonly property real size: banner.height * (0.9 + Math.random() * 0.7)
                            width: size; height: size; radius: size / 2
                            x: Math.random() * banner.width - size / 2
                            y: Math.random() * banner.height - size / 2
                            color: Qt.alpha(root.stateColor, 0.07)
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
                            function drift() {
                                ax.to = Math.random() * banner.width - size / 2
                                ay.to = Math.random() * banner.height - size / 2
                                ax.duration = ay.duration = 3500 + Math.random() * 4500
                                ax.restart(); ay.restart()
                            }
                            NumberAnimation { id: ax; target: blob; property: "x"; easing.type: Easing.InOutSine }
                            NumberAnimation { id: ay; target: blob; property: "y"; easing.type: Easing.InOutSine
                                              onFinished: if (root.expanded) blob.drift() }
                            Connections {
                                target: root
                                function onExpandedChanged() { if (root.expanded) blob.drift(); else { ax.stop(); ay.stop() } }
                            }
                            Component.onCompleted: if (root.expanded) drift()
                        }
                    }
                }
                ColumnLayout {
                    id: bannerContent
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: Kirigami.Units.gridUnit * 0.9 }
                    spacing: Kirigami.Units.smallSpacing
                    RowLayout {
                        Layout.fillWidth: true
                        IconView { // wordmark: follows the theme text color (white on dark, black on light), not the state
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                            Layout.preferredWidth: Layout.preferredHeight * 748 / 166
                            value: Qt.resolvedUrl("../icons/twingate-wordmark.png").toString()
                            tintColor: Kirigami.Theme.textColor
                        }
                        Item { Layout.fillWidth: true }
                        QQC2.Switch {
                            enabled: root.link !== "missing" && !root.pending
                            checked: root.active
                            onToggled: {
                                root.setOnline(checked)
                                checked = Qt.binding(() => root.active) // a click breaks the binding otherwise
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.largeSpacing - Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.gridUnit * 0.9 - Kirigami.Units.smallSpacing
                        height: 1
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
                    }
                    TextMetrics { id: labelMetrics; font.pixelSize: Kirigami.Units.gridUnit * 0.75; text: "Network" }
                    Repeater {
                        model: ["status", "uptime", "network", "address"]
                        RowLayout {
                            id: fact
                            readonly property var info: {
                                switch (modelData) {
                                case "status":  return { k: i18n("Status"), v: root.pending ? i18n("Working…") : root.title,
                                                         icon: "network-vpn-symbolic", color: root.stateColor }
                                case "uptime":  return { k: i18n("Uptime"), v: root.online ? root.uptimeText : "",
                                                         icon: "chronometer-symbolic", mono: true }
                                case "network": return { k: i18n("Network"), v: root.online ? root.networkName : "", icon: "network-workgroup-symbolic" }
                                default:        return { k: i18n("Address"), v: root.online ? root.host : "", icon: "globe-symbolic" }
                                }
                            }
                            visible: info.v !== ""
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing
                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignTop
                                source: fact.info.icon
                                isMask: true
                                color: Kirigami.Theme.textColor
                                opacity: 0.7
                            }
                            QQC2.Label {
                                Layout.preferredWidth: Math.ceil(labelMetrics.width) + Kirigami.Units.smallSpacing
                                Layout.alignment: Qt.AlignTop
                                text: fact.info.k
                                opacity: 0.7
                                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: fact.info.v
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.WrapAnywhere // long hostnames have no spaces to wrap at
                                color: fact.info.color || Kirigami.Theme.textColor
                                font.family: fact.info.mono ? "monospace" : Kirigami.Theme.defaultFont.family
                                font.bold: true
                                font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            }
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
                icon.name: root.link === "auth" ? "user-identity-symbolic" : "network-disconnect-symbolic"
                icon.color: Kirigami.Theme.disabledTextColor
                icon.width: Kirigami.Units.iconSizes.huge
                icon.height: Kirigami.Units.iconSizes.huge
                text: root.link === "missing" ? i18n("Install the Twingate client")
                    : root.link === "unknown" ? i18n("Couldn't read the status")
                    : root.link === "auth" ? i18n("Sign in to Twingate")
                    : i18n("Twingate is off")
                explanation: root.link === "missing" ? i18n("This widget needs the twingate command-line tool.")
                           : root.link === "unknown" ? root.statusText
                           : root.link === "auth" ? i18n("Twingate needs you to sign in before it can connect.")
                           : i18n("Use the switch to connect.")
                helpfulAction: root.link === "auth" && root.authUrl ? signInAction : null
            }

            RowLayout { // heading: dim title, count on the right
                visible: root.online
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 0.9
                Layout.rightMargin: Kirigami.Units.gridUnit * 0.9
                Layout.topMargin: Kirigami.Units.gridUnit * 0.9
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("Resources")
                    opacity: 0.6
                }
                QQC2.Label {
                    text: root.items.length
                    opacity: 0.6
                }
            }
            QQC2.ScrollView {
                visible: root.online
                Layout.fillWidth: true
                Layout.fillHeight: true
                ListView {
                    clip: true
                    model: root.items
                    delegate: QQC2.ItemDelegate {
                        id: row
                        width: ListView.view.width
                        text: modelData.name
                        leftPadding: Kirigami.Units.gridUnit * 0.9
                        rightPadding: Kirigami.Units.gridUnit * 0.9
                        topPadding: Kirigami.Units.largeSpacing * 1.5
                        bottomPadding: Kirigami.Units.largeSpacing * 1.5
                        Kirigami.Separator { // thin rule between rows, so the items read as a list
                            visible: !!row.ListView.view && index < row.ListView.view.count - 1
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                                      leftMargin: Kirigami.Units.gridUnit * 0.9; rightMargin: Kirigami.Units.gridUnit * 0.9 }
                        }
                        HoverHandler { cursorShape: row.openable ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        Component.onCompleted: if (openable) root.fetchIcon(modelData.open_url)
                        readonly property bool openable: modelData.can_open_in_browser && !!modelData.open_url
                        // Twingate gives no separate port field, so read it from the URL: "http://host:8384" -> "8384".
                        readonly property string port: { const m = (modelData.open_url || "").match(/^[a-z]+:\/\/[^\/:]+:(\d+)/); return m ? m[1] : "" }
                        onClicked: if (openable) Qt.openUrlExternally(modelData.open_url)
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            Item {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    visible: favicon.status !== Image.Ready
                                    source: row.openable ? "internet-services" : "network-server"
                                    opacity: 0.8
                                }
                                Image {
                                    id: favicon
                                    anchors.fill: parent
                                    source: row.openable ? (root.icons[modelData.open_url] || "") : ""
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                QQC2.Label {
                                    text: modelData.name
                                    color: row.openable ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor
                                    font.bold: true
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                                    font.underline: row.openable && row.hovered
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                QQC2.Label {
                                    text: (modelData.alias || modelData.address) + (row.port ? ":" + row.port : "")
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.65
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            Kirigami.Icon { // "opens in your browser"
                                visible: row.openable
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: "external-link-symbolic"
                                isMask: true
                                color: Kirigami.Theme.linkColor
                            }
                        }
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
            // The setting swaps the two: left-click opens the popup and middle-click toggles, or the other way round.
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton && !root.cfg.middleClick) return
                const toggle = (mouse.button === Qt.MiddleButton) === (root.cfg.clickAction === 0)
                if (toggle) root.setOnline(!root.active)
                else root.expanded = !root.expanded
            }
        }
    }
}
