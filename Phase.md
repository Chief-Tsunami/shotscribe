# Phase

## Current phase: Ship
As of 2026-08-12 (commit 9d2c9a2), all four "doors" to the engine are
built and shipped: CLI, MCP server, menu bar app, and the `/screenshot`
skill. The menu bar app is Developer-ID signed, notarized, and stapled
(app + DMG, commit a5b221d) — distribution mechanics work end to end.

## Gate to next phase (maintain)
- README.md's own roadmap still lists two open items: a "backlog sweep"
  (rename captures that landed while the app wasn't running) and a
  WidgetKit widget. Closing those — or explicitly deferring them — is a
  reasonable gate before calling this "maintain" rather than "ship."
- TODO: no distribution channel (e.g. a GitHub release, Homebrew tap)
  confirmed yet for the notarized DMG sitting in `dist/` — worth checking
  before treating "ship" as complete.
