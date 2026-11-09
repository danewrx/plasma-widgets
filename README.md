# plasma-widgets

KDE Plasma 6 widgets.

| Widget | What it does | Folder |
|---|---|---|
| Mullvad VPN | Status, quick toggle and a location picker with a map for the Mullvad VPN | [`org.danewrx.mullvad`](org.danewrx.mullvad) |
| Twingate | Status, connect switch and a list of your resources for the Twingate Linux client | [`org.danewrx.twingate`](org.danewrx.twingate) |

## Install

```bash
kpackagetool6 -t Plasma/Applet -i <widget folder>
```

Use `-u` instead of `-i` to update. Then add the widget from the panel's *Add Widgets*.

## Issues and contributing
Please open [issues](../../issues/new/choose) using the forms, and see [CONTRIBUTING.md](CONTRIBUTING.md) for commit and PR conventions. Questions and ideas go in [Discussions](../../discussions).
