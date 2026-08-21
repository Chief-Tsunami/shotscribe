# Phase

## Current phase: Ship
As of 2026-08-12 (commit 9d2c9a2), all four "doors" to the engine are
built and shipped: CLI, MCP server, menu bar app, and the `/screenshot`
skill. The menu bar app is Developer-ID signed, notarized, and stapled
(app + DMG, commit a5b221d) — distribution mechanics work end to end.

## 2026-08-20 — extracted the face
`ShotScribeUI` split out of the menu bar executable so anything can host
ShotScribe; Toolbelt admitted it the same day as one of its first two organs.
No engine changes. Details in `History.md`.

## Gate to next phase (maintain)
- README.md's own roadmap still lists two open items: a "backlog sweep"
  (rename captures that landed while the app wasn't running) and a
  WidgetKit widget. Closing those — or explicitly deferring them — is a
  reasonable gate before calling this "maintain" rather than "ship."
- TODO: no distribution channel (e.g. a GitHub release, Homebrew tap)
  confirmed yet for the notarized DMG sitting in `dist/` — worth checking
  before treating "ship" as complete.

## Discovered sub-issues
- **2026-08-20 — `swift test` was blocked, then unblocked the same day.**
  `xcode-select` had been pointing at CommandLineTools, so `XCTest` was missing
  and the test target would not compile. Once corrected, `ShotScribeCoreTests`
  ran green: 13 tests, 0 failures. The `ShotScribeUI` extraction is therefore
  covered by both the suite and the hand verification below.
- **2026-08-20 — the notarized v0.4.0 DMG predates `ShotScribeUI`.** The
  extraction changed no engine behaviour, but the shipped artifact no longer
  matches the tree. Re-run the ship stage before pointing anyone at `dist/`.
