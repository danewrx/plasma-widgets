# Contributing

## Commits and PRs
Use `type(widget): message`, e.g. `feat(mullvad): add a reconnect button`. Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert. The widget name is the scope. A hook enforces this locally and a check enforces it on PR titles.

PRs get a type label from the title: `feat`/`perf` → `enhancement`, `fix` → `bug`, `docs` → `documentation`, and `chore`/`refactor`/`style`/`test`/`build`/`ci`/`revert` → `maintenance`. The widget label comes from the folders the PR changes.

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
2. Add it to the issue form dropdowns in `.github/ISSUE_TEMPLATE/`, to `.github/labeler.yml`, and add a collapsible `<details>` block for it under *Widgets* in the README (copy the Mullvad one).
3. Create a `widget: <name>` label.
4. Set up releases:
   - Give its `metadata.json` a full semver `Version` such as `"0.0.0"`. release-please silently skips a version it can't parse as `x.y.z` (a plain `"1.0"` is skipped).
   - Add a block under `packages` in `release-please-config.json` (copy the mullvad one and change the folder and `component`) and an entry in `.release-please-manifest.json` starting at `"0.0.0"`. The workflow itself needs no changes.
   - The first release's version then follows the commit types from `0.0.0` (`feat` → `0.1.0`). To start at `1.0.0` instead, put `Release-As: 1.0.0` as a footer in the description of that widget's first PR. Don't pin `release-as` in the config: it stays in force until removed.

## Releases
Releases are automated with [release-please](https://github.com/googleapis/release-please), driven by the PR titles (squash-merged commits) on `main`:

1. Merging a `feat`/`fix`/… PR makes release-please open or update a **release PR** for that widget. It bumps `KPlugin.Version` in `metadata.json` (`feat` → minor, `fix` → patch, `!` → major) and updates the widget's `CHANGELOG.md`.
2. Merging the release PR tags it (`mullvad-v1.2.0`) and creates the GitHub release.
3. The `package` job then builds `<id>-<version>.plasmoid` with `scripts/package.sh`, attaches it to the release, and prints a KDE Store upload checklist in the run summary.

Publishing to the KDE Store is still manual: the store has no documented upload API yet.

One-time setup: Repo settings → Actions → General → *Workflow permissions*: allow read and write, and tick *Allow GitHub Actions to create and approve pull requests*.

Adding a widget's release setup is step 4 of [Adding a widget](#adding-a-widget).
