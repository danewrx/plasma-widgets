import QtQuick
import QtQuick.Controls as QQC2
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
                    else if (list.length && (m = l.match(/^\t(\S.*) \(([a-z]+)\) @/)))
                        list[list.length - 1].cities.push({ name: m[1], code: m[2] })
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
            root.vpnState = head.startsWith("connected") ? "connected"
                          : head.startsWith("connecting") ? "connecting"
                          : head.startsWith("disconnected") ? "disconnected"
                          : head.startsWith("blocked") ? "blocked" : "unknown"
            root.detail = out.split("\n").slice(1).map(l => l.trim()).join("\n")
        }
    }

    function refresh() { exec.connectSource("mullvad status") }
    function loadRelays() { exec.connectSource("mullvad relay list"); exec.connectSource("mullvad relay get") }
    // Codes come from the parser above ([a-z]+ only), so they are safe in a shell command.
    function selectLocation(country, city) {
        currentCountry = country
        currentCity = city || ""
        exec.connectSource("mullvad relay set location " + country + (city ? " " + city : "") + " && mullvad connect")
    }
    onExpandedChanged: if (root.expanded) loadRelays()

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }


    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24

        Rectangle {
            id: banner
            Layout.fillWidth: true
            implicitHeight: bannerContent.implicitHeight + Kirigami.Units.largeSpacing * 2
            color: root.stateColor
            // black or white text, whichever reads on the chosen color
            readonly property color fg: color.hslLightness > 0.6 ? "black" : "white"

            ColumnLayout {
                id: bannerContent
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
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
                            text: root.vpnState.charAt(0).toUpperCase() + root.vpnState.slice(1)
                            color: banner.fg
                            opacity: 0.85
                        }
                    }
                    QQC2.Switch {
                        checked: root.active
                        onToggled: {
                            exec.connectSource(checked ? "mullvad connect" : "mullvad disconnect")
                            checked = Qt.binding(() => root.active) // a click breaks the binding otherwise
                        }
                    }
                }
                // Relay, features, visible location… straight from `mullvad status`, padding squeezed out.
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.detail.replace(/ {2,}/g, " ")
                    color: banner.fg
                    wrapMode: Text.Wrap
                    font.pixelSize: Kirigami.Units.gridUnit * 0.75
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.lastError
                    color: banner.fg
                    wrapMode: Text.Wrap
                }
            }
        }
        Kirigami.Separator { Layout.fillWidth: true }
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
