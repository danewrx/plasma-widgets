<h1 align="center">plasma-widgets</h1>

<p align="center">
  Collection of widgets I have created for KDE Plasma
</p>

<p align="center">
  <img alt="Plasma 6" src="https://img.shields.io/badge/KDE%20Plasma-6-1d99f3?logo=kde&logoColor=white">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green">
</p>

## Widgets

Click a widget to see what it does and how it looks.

<details>
<summary><b>Mullvad VPN</b> - Plasmoid to interact with Mullvad VPN</summary>

<br>

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

</details>

## Install

> [!TIP]
> Installing from the KDE Store is recommended.

<details>
<summary><b>KDE Store</b></summary>

Right-click the panel → **Add Widgets…** → **Get New Widgets…** → **Download New Plasma Widgets…**, search for the widget by name and click **Install**.
<!-- Once the product is live, add its link here: [store.kde.org listing](https://store.kde.org/p/XXXXXXX) -->

</details>

<details>
<summary><b>Manual, from a release</b></summary>

Download the `.plasmoid` file for a widget from the [Releases](../../releases) page, then:

```bash
kpackagetool6 -t Plasma/Applet -i <file>.plasmoid
```

Right-click the panel → **Add Widgets**, and search for the widget by name.

</details>

<details>
<summary><b>From source</b></summary>

Clone this repo and point the command at the widget's folder:

```bash
kpackagetool6 -t Plasma/Applet -i <widget folder>
```

</details>

### Update and remove

| | Command |
|---|---|
| Update | `kpackagetool6 -t Plasma/Applet -u <file or folder>` |
| Remove | `kpackagetool6 -t Plasma/Applet -r <widget id>` (e.g. `org.danewrx.mullvad`) |

The shell caches widget code, so if a panel instance doesn't pick up an update, restart it with `systemctl --user restart plasma-plasmashell`.

## Issues and contributing

Found a bug or want a feature? Open an [issue](../../issues/new/choose) using the forms. Questions and ideas go in [Discussions](../../discussions). To contribute, read [CONTRIBUTING.md](CONTRIBUTING.md) for the commit and PR conventions, how to test a widget, and how releases work.

## License

[MIT](LICENSE)
