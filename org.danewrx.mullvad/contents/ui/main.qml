import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string vpnState: "unknown"   // connected | connecting | disconnected | blocked | unknown
    property string detail: ""
    property string lastError: ""
    property var countries: []            // [{name, code, cities: [{name, code}]}] from `mullvad relay list`
    property string currentCountry: ""    // codes from `mullvad relay get`
    property string currentCity: ""
    property string relay: ""             // e.g. ca-tor-wg-201 (empty when not connected)
    property string visibleLocation: ""   // e.g. "Canada, Toronto" (also known while disconnected)
    property bool detailsOpen: false
    readonly property var featureChips: {
        const f = detail.match(/Features:\s*(.+)/)
        return f ? f[1].split(/,\s*/) : []
    }
    readonly property var detailRows: {
        const imp = [], extra = []
        for (const l of detail.split("\n")) {
            const m = l.match(/^([^:]+):\s*(.*)$/)
            if (!m) continue
            if (m[1] === "Visible location") {
                // IPs arrive a moment after the location, so they are optional: "Brazil, Sao Paulo[. IPv4: x[, IPv6: y]]"
                const v = m[2].match(/^(.*?)(?:\.\s+(IPv[46]:.*))?$/)
                imp.push({ k: "Location", v: v[1].replace(/\.$/, ""), important: true })
                for (const part of (v[2] || "").split(/,\s*/)) {   // no matchAll in QML's JS engine
                    const ip = part.match(/^(IPv[46]):\s*(\S+)/)
                    if (ip) imp.push({ k: ip[1], v: ip[2], important: true })
                }
            } else if (m[1] === "Relay") {
                // "exit-relay [via entry-relay] [(note)]", e.g. "ua-iev-wg-002 via ro-buh-wg-012 (multihop enabled ...)"
                const r = m[2].match(/^(.*?)(?: via (\S+))?(?: \((.*)\))?$/)
                extra.push({ k: "Relay", v: r[1] })
                if (r[2]) extra.push({ k: "Via", v: r[2] })
                if (r[3]) extra.push({ note: r[3] })
            } else if (m[1] !== "Features") extra.push({ k: m[1], v: m[2] })
        }
        return imp.concat(extra)
    }
    property string pending: ""
    property double pendingSince: 0
    property bool picking: false          // popup shows the location list instead of the map
    // Where to put the map pin: the relay's city when connected, else the middle of the visible country.
    readonly property var pin: {
        const p = relay.split("-"), c = countries.find(x => x.code === p[0])
        const city = c && c.cities.find(x => x.code === p[1])
        if (city) return city
        // The relay list says "UK"/"USA" where the status line says "United Kingdom"/"United States".
        const alias = { "United Kingdom": "UK", "United States": "USA" }, name = visibleLocation.split(",")[0].trim()
        const byName = countries.find(x => x.name === (alias[name] || name))
        return byName ? byName.center : null
    }
    readonly property bool connecting: vpnState === "connecting"
    readonly property bool active: vpnState === "connected" || vpnState === "connecting"
    readonly property var cfg: Plasmoid.configuration
    readonly property string iconValue: active ? cfg.lockIcon : cfg.unlockIcon
    readonly property url iconFallback: Qt.resolvedUrl("../icons/" + (active ? "lock" : "unlock") + ".svg")
    // Order matches the list in configAppearance.qml.
    function systemColor(i) {
        return [Kirigami.Theme.textColor, Kirigami.Theme.positiveTextColor, Kirigami.Theme.negativeTextColor,
                Kirigami.Theme.neutralTextColor, Kirigami.Theme.highlightColor, Kirigami.Theme.linkColor,
                Kirigami.Theme.disabledTextColor][i]
    }
    readonly property color stateColor: cfg.colorMode === 0 ? (active ? "#1f8a3b" : "#da4453")
                                      : cfg.colorMode === 1 ? systemColor(active ? cfg.activeSystem : cfg.inactiveSystem)
                                      : (active ? cfg.activeColor : cfg.inactiveColor)

    toolTipMainText: "Mullvad: " + vpnState
    toolTipSubText: detail || lastError

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            const out = (data["stdout"] || "").trim()
            if (source === "mullvad relay list") {
                // Countries are unindented ("Albania (al)"), cities one tab in ("\tTirana (tia) @ ..."),
                // servers two tabs in (ignored).
                const list = []
                for (const l of out.split("\n")) {
                    let m
                    if ((m = l.match(/^(\S.*) \(([a-z]{2})\)\s*$/))) list.push({ name: m[1], code: m[2], cities: [] })
                    // The CLI prints signed numbers (east/north positive) with fixed N/W letters, so ignore the letters.
                    else if (list.length && (m = l.match(/^\t(\S.*) \(([a-z]+)\) @ (-?[\d.]+)°[NS], (-?[\d.]+)°[EW]/)))
                        list[list.length - 1].cities.push({ name: m[1], code: m[2], lat: +m[3], lon: +m[4] })
                }
                // shortcut: a plain average of a country's cities, wrong only for countries spanning the 180° meridian.
                for (const c of list) {
                    const n = c.cities.length || 1
                    c.center = { lat: c.cities.reduce((a, x) => a + x.lat, 0) / n, lon: c.cities.reduce((a, x) => a + x.lon, 0) / n }
                }
                root.countries = list
                return
            }
            if (source === "mullvad relay get") {
                const m = out.match(/Location:\s+(?:country|city) (\w+)(?: (\w+))?/)
                root.currentCountry = m ? m[1] : ""
                root.currentCity = m && m[2] && /Location:\s+city/.test(out) ? m[2] : ""
                return
            }
            if (source !== "mullvad status") { refresh(); loadRelays(); return }
            const err = (data["stderr"] || "").toString().trim()
            root.lastError = err || (data["exit code"] ? "exit " + data["exit code"] : "")
            const head = out.split("\n")[0].toLowerCase()
            let st = head.startsWith("connected") ? "connected"
                   : head.startsWith("connecting") ? "connecting"
                   : head.startsWith("disconnected") ? "disconnected"
                   : head.startsWith("blocked") ? "blocked" : "unknown"
            if (root.pending) {
                const caughtUp = root.pending === "connect" ? (st === "connecting" || st === "connected") : st === "disconnected"
                if (caughtUp || Date.now() - root.pendingSince > 10000) root.pending = ""
                else st = root.vpnState // stale reading from before the daemon saw our request
            }
            root.vpnState = st
            root.detail = out.split("\n").slice(1).map(l => l.trim()).join("\n")
            const rel = out.match(/Relay:\s+(\S+)/),
                  loc = out.match(/Visible location:\s+(.*?)(?:\.\s+IPv[46]|$)/m)
            root.relay = rel ? rel[1] : ""
            root.visibleLocation = loc ? loc[1].trim() : ""
        }
    }

    // Show the new state at once instead of waiting for the next poll; the poll then confirms or corrects it.
    function setConnected(on) {
        vpnState = on ? "connecting" : "disconnected"
        pending = on ? "connect" : "disconnect"
        pendingSince = Date.now()
        exec.connectSource(on ? "mullvad connect" : "mullvad disconnect")
    }
    function refresh() { exec.connectSource("mullvad status") }
    function loadRelays() { exec.connectSource("mullvad relay list"); exec.connectSource("mullvad relay get") }
    // Codes come from the parser above ([a-z]+ only), so they are safe in a shell command.
    function selectLocation(country, city) {
        currentCountry = country
        currentCity = city || ""
        picking = false
        vpnState = "connecting"
        pending = "connect"
        pendingSince = Date.now()
        exec.connectSource("mullvad relay set location " + country + (city ? " " + city : "") + " && mullvad connect")
    }
    onExpandedChanged: { if (root.expanded) loadRelays(); else picking = false }

    Timer {
        interval: root.connecting || root.pending ? 1000 : 5000 // watch closely while a connection is being made
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }


    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28

        // ---- banner: switch + every detail from `mullvad status` ----
        Rectangle {
            id: banner
            anchors { top: parent.top; left: parent.left; right: parent.right }
            z: 2
            height: implicitHeight
            implicitHeight: bannerContent.implicitHeight + Kirigami.Units.largeSpacing * 2
            Behavior on implicitHeight { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } // dropdown
            color: root.stateColor
            clip: true
            // black or white text, whichever reads on the chosen color
            readonly property color fg: color.hslLightness > 0.6 ? "black" : "white"
            // loading sweep, only while connecting
            Rectangle {
                id: sweep
                visible: root.connecting
                width: banner.width * 0.6
                height: banner.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(banner.fg, 0) }
                    GradientStop { position: 0.5; color: Qt.alpha(banner.fg, 0.3) }
                    GradientStop { position: 1.0; color: Qt.alpha(banner.fg, 0) }
                }
                NumberAnimation on x {
                    running: root.connecting
                    from: -sweep.width
                    to: banner.width
                    duration: 1400
                    loops: Animation.Infinite
                }
            }
            ColumnLayout {
                id: bannerContent
                // top-anchored, not fill: the banner height animates, and a stretched layout re-spaces its children
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: Kirigami.Units.largeSpacing }
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    IconView {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                        value: root.iconValue
                        fallback: root.iconFallback
                        tint: root.cfg.tintIcons
                        tintColor: banner.fg
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: "MULLVAD VPN"
                            color: banner.fg
                            elide: Text.ElideRight
                            font.bold: true
                            font.pixelSize: Kirigami.Units.gridUnit
                        }
                        QQC2.Label {
                            text: root.vpnState.charAt(0).toUpperCase() + root.vpnState.slice(1) + (root.connecting ? "…" : "")
                            color: banner.fg
                            opacity: 0.85
                        }
                    }
                    QQC2.Switch {
                        checked: root.active
                        onToggled: {
                            root.setConnected(checked)
                            checked = Qt.binding(() => root.active) // a click breaks the binding otherwise
                        }
                    }
                }
                Rectangle { // divider
                    Layout.fillWidth: true
                    visible: root.detailRows.length > 0 && !root.connecting
                    height: 1
                    color: Qt.alpha(banner.fg, 0.3)
                }
                Repeater {
                    model: root.connecting ? [] : root.detailRows
                    ColumnLayout {
                        visible: modelData.important === true || root.detailsOpen
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            visible: modelData.k !== undefined
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing
                            QQC2.Label {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                                Layout.alignment: Qt.AlignTop
                                text: modelData.k || ""
                                elide: Text.ElideRight
                                color: banner.fg
                                opacity: 0.7
                                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: modelData.v || ""
                                color: banner.fg
                                wrapMode: Text.WrapAnywhere // long hostnames have no spaces to wrap at
                                font.bold: true
                                font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            }
                        }
                        QQC2.Label {
                            visible: modelData.note !== undefined
                            Layout.fillWidth: true
                            text: modelData.note || ""
                            color: banner.fg
                            opacity: 0.7
                            wrapMode: Text.Wrap
                            font.italic: true
                            font.pixelSize: Kirigami.Units.gridUnit * 0.7
                        }
                    }
                }
                Flow { // feature pills
                    visible: !root.connecting && root.detailsOpen && root.featureChips.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.featureChips
                        Rectangle {
                            width: chipLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
                            height: chipLabel.implicitHeight + Kirigami.Units.smallSpacing
                            radius: height / 2
                            color: Qt.alpha(banner.fg, 0.15)
                            border.color: Qt.alpha(banner.fg, 0.5)
                            QQC2.Label {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: banner.fg
                                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                            }
                        }
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: text !== "" && !root.connecting
                    text: root.lastError
                    color: banner.fg
                    wrapMode: Text.Wrap
                }
                Kirigami.Icon { // expand / collapse the details
                    visible: !root.connecting && (root.detailRows.some(r => !r.important) || root.featureChips.length > 0)
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: root.detailsOpen ? "arrow-up" : "arrow-down"
                    isMask: true
                    color: banner.fg
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Kirigami.Units.smallSpacing
                        onClicked: root.detailsOpen = !root.detailsOpen
                    }
                }
            }
        }

        // ---- map, with the location list sliding up over it ----
        Item {
            id: mapView
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: switchButton.top }
            clip: true

            Rectangle { anchors.fill: parent; color: Kirigami.Theme.backgroundColor }
            Image {
                id: world
                readonly property real zoom: Math.max(4, 2 * mapView.height / mapView.width + 0.01)
                readonly property point px: root.pin ? Qt.point((root.pin.lon + 180) / 360 * width, (90 - root.pin.lat) / 180 * height)
                                                     : Qt.point(width / 2, height / 2)
                width: mapView.width * zoom
                height: width / 2
                x: Math.min(0, Math.max(mapView.width - width, mapView.width / 2 - px.x))
                y: Math.min(0, Math.max(mapView.height - height, mapView.height * 0.6 - px.y))
                source: Qt.resolvedUrl("../images/world.svg")
                sourceSize: Qt.size(width, height)
                opacity: 0.15
                layer.enabled: true // the SVG is white: tint it with the theme text color
                layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: Kirigami.Theme.textColor }
            }
            Image {
                x: world.x; y: world.y
                width: world.width; height: world.height
                source: Qt.resolvedUrl("../images/borders.svg")
                sourceSize: Qt.size(width, height)
                opacity: 0.9
                layer.enabled: true
                layer.effect: MultiEffect { brightness: 1.0; colorization: 1.0; colorizationColor: Kirigami.Theme.backgroundColor }
            }
            Item {
                visible: root.pin !== null
                x: world.x + world.px.x
                y: world.y + world.px.y
                Rectangle { anchors.centerIn: parent; width: Kirigami.Units.gridUnit * 3; height: width; radius: width / 2
                            color: root.stateColor; opacity: 0.3 }
                Rectangle { anchors.centerIn: parent; width: Kirigami.Units.gridUnit * 0.9; height: width; radius: width / 2
                            color: root.stateColor; border.color: Kirigami.Theme.textColor; border.width: 2 }
            }

            Rectangle {
                id: locationPanel
                width: parent.width
                height: parent.height - banner.height
                y: root.picking ? banner.height : parent.height
                visible: y < parent.height
                color: Kirigami.Theme.backgroundColor
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } } // picker slide
                QQC2.ScrollView {
                    anchors.fill: parent
                    ListView {
                        clip: true
                        model: root.countries
                        delegate: ColumnLayout {
                            id: row
                            readonly property var country: modelData
                            property bool open: false
                            width: ListView.view.width
                            spacing: 0
                            RowLayout {
                                spacing: 0
                                QQC2.ItemDelegate {
                                    Layout.fillWidth: true
                                    text: row.country.name
                                    highlighted: row.country.code === root.currentCountry && root.currentCity === ""
                                    onClicked: root.selectLocation(row.country.code, "")
                                }
                                QQC2.ToolButton {
                                    icon.name: row.open ? "arrow-up" : "arrow-down"
                                    visible: row.country.cities.length > 0
                                    onClicked: row.open = !row.open
                                    QQC2.ToolTip.text: i18n("Cities")
                                    QQC2.ToolTip.visible: hovered
                                }
                            }
                            Repeater {
                                model: row.open ? row.country.cities : []
                                delegate: QQC2.ItemDelegate {
                                    Layout.fillWidth: true
                                    leftPadding: Kirigami.Units.gridUnit * 1.5
                                    text: modelData.name
                                    highlighted: row.country.code === root.currentCountry && modelData.code === root.currentCity
                                    onClicked: root.selectLocation(row.country.code, modelData.code)
                                }
                            }
                        }
                    }
                }
            }
        }

        QQC2.Button {
            id: switchButton
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Kirigami.Units.smallSpacing }
            text: root.picking ? i18n("Close") : i18n("Switch location")
            icon.name: root.picking ? "go-down" : "go-up"
            onClicked: {
                if (!root.picking) { root.loadRelays(); root.detailsOpen = false }
                root.picking = !root.picking
            }
        }
    }

    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

        IconView {
            id: icon
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * root.cfg.iconScale / 100 // 100% = the full slot
            height: width
            value: root.iconValue
            fallback: root.iconFallback
            opacity: root.vpnState === "connecting" ? 0.5 : 1.0
            tint: root.cfg.tintIcons
            tintColor: root.stateColor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    Component.onCompleted: loadRelays()
}
