# Roadmap

Now / Next / Later for shotscribe. Derived 2026-08-12 from README.md's own
checklist plus `git log`.

## Now
- TODO: no in-progress work identified from repo state — the last commit
  (9d2c9a2) shipped the /screenshot skill with a clean working tree.

## Next
- Backlog sweep: rename captures that landed while the app wasn't running.

## Later
- WidgetKit widget — a one-tap App Intent front door.

## Done
- Core engine + CLI (`rename` / `label` / `watch`)
- MCP server target (`shotscribe-mcp`)
- `MenuBarExtra` app (`scripts/package-app.sh`)
- App icon, welcome window, configurable folder, launch at login
- Notarized distribution (Developer ID signed, notarized, stapled — app +
  DMG; commit a5b221d). Note: README.md's own checklist still shows this
  item unchecked — worth a quick fix there.
