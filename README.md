<h1 align="center">plasma-widgets</h1>

<p align="center">
  Widgets for the KDE Plasma 6 panel, built to look and feel native.
</p>

<p align="center">
  <img alt="Plasma 6" src="https://img.shields.io/badge/KDE%20Plasma-6-1d99f3?logo=kde&logoColor=white">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green">
</p>

## Widgets

### Mullvad VPN

<p align="center">
  <img src="docs/screenshots/mullvad-hero.png" width="720" alt="Mullvad VPN widget for Plasma">
</p>

Control Mullvad VPN from the panel: see your connection at a glance, switch it on or off, and pick a country or city on a map.

- Tray icon that shows the state, tinted to your theme or your own colors
- Popup with connection details, a world map and a location picker
- Quick toggle by right-click, middle-click or a keyboard shortcut
- Clear messages if the `mullvad` CLI or its service is missing

[Full documentation →](org.danewrx.mullvad/README.md)

<p align="center">
  <img src="docs/screenshots/mullvad-popup.png" width="31%" alt="Popup while connected">
  <img src="docs/screenshots/mullvad-details.png" width="31%" alt="Expanded connection details">
  <img src="docs/screenshots/mullvad-locations.png" width="31%" alt="Location picker">
</p>

## Install

**From the KDE Store (easiest).** Right-click the panel → **Add Widgets…** → **Get New Widgets…** → **Download New Plasma Widgets…**, search for the widget by name and click **Install**.
<!-- Once the product is live, add its link here: [store.kde.org listing](https://store.kde.org/p/XXXXXXX) -->

**From a release.** Download the `.plasmoid` file for a widget from the [Releases](../../releases) page, then:

```bash
kpackagetool6 -t Plasma/Applet -i <file>.plasmoid
```

Right-click the panel → **Add Widgets**, and search for the widget by name.

| | Command |
|---|---|
| Update | `kpackagetool6 -t Plasma/Applet -u <file>.plasmoid` |
| Remove | `kpackagetool6 -t Plasma/Applet -r <widget id>` (e.g. `org.danewrx.mullvad`) |

To install from a clone of this repo instead, point `-i` or `-u` at the widget's folder. The shell caches widget code, so if a panel instance doesn't pick up an update, restart it with `systemctl --user restart plasma-plasmashell`.

## Issues and contributing

Found a bug or want a feature? Open an [issue](../../issues/new/choose) using the forms. Questions and ideas go in [Discussions](../../discussions). To contribute, read [CONTRIBUTING.md](CONTRIBUTING.md) for the commit and PR conventions, how to test a widget, and how releases work.

## License

[MIT](LICENSE)
