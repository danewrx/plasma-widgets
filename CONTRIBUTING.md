# Contributing

## Commits and PRs
Use `type(widget): message`, e.g. `feat(mullvad): add a reconnect button`. Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert. The widget name is the scope. A hook enforces this locally and a check enforces it on PR titles.

Enable the hook once per clone:

```bash
git config core.hooksPath .githooks
```

## Testing a widget
Install or update it, then run it in a window:

```bash
kpackagetool6 -t Plasma/Applet -u <widget folder>
plasmoidviewer -a <widget id> -l topedge -f horizontal
```

Widget code is cached by the shell, so restart it to see changes in the panel: `systemctl --user restart plasma-plasmashell`.

## Adding a widget
1. Put it in its own folder named after its plugin id (e.g. `org.danewrx.mullvad`).
2. Add it to the issue form dropdowns in `.github/ISSUE_TEMPLATE/`, to `.github/labeler.yml`, and to the table in the README.
3. Create a `widget: <name>` label.
