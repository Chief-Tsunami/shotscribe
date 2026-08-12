# shotscribe

Turn `Screenshot 2026-08-11 at 3.41.07 PM.png` into
`2026-08-11 1541 AWS Billing Console.png` — automatically, on-device, and
findable later.

`shotscribe` watches your screenshot folder, reads the text in each new capture
with Apple's **on-device Vision OCR** (nothing leaves your machine), asks a
local LLM for a 2–3 word title, and renames the file: **date first** (so
name-sort stays chronological) then a scannable label. macOS default capture
names are the only ones it touches — a file you named yourself is never
renamed.

It's one small, single-purpose tool. The logic lives in a reusable core
(`ShotScribeCore`) so the same engine backs the CLI today and — next — an MCP
server, a menu-bar app, and a widget.

## Whose Claude is it?

**Yours.** ShotScribe ships no API keys and has no account of its own. When
Claude titling is on, it drives the `claude` CLI installed on *your* machine,
which runs on *your* Claude subscription — the same one you use in your
terminal. Install [Claude Code](https://claude.com/claude-code), run
`claude` once to sign in, and ShotScribe picks it up automatically. No Claude
Code? Everything still works with the offline keyword titler — just blunter
labels.

## The "connect to Claude" part

Titling is a swappable seam (`Titler`):

- **`ClaudeTitler`** shells out to the local [Claude Code](https://claude.com/claude-code)
  CLI (`claude -p`), sandboxed (no tools, no MCP) since the prompt carries text
  pulled off your screen. This is the default when `claude` is installed.
- **`KeywordTitler`** needs no network and no Claude — it picks the salient words
  straight from the OCR text. So the tool is still useful to anyone.

And the inversion also exists: **`shotscribe-mcp`** is an MCP server (stdio)
that lets Claude Code / Cowork call the same engine as tools *during a
session* — there, the calling model IS the intelligence, so the server only
does the mechanical, on-device parts and takes the model's title as input.

## Install

```bash
git clone <repo> shotscribe && cd shotscribe
swift build -c release
cp .build/release/shotscribe /usr/local/bin/   # or anywhere on your PATH
```

## Usage

```bash
# Print the title shotscribe would give a shot (no rename) — the quickest way
# to see the Claude connection working end-to-end:
shotscribe label "~/Desktop/Screenshot 2026-08-11 at 3.41.07 PM.png"

# Rename one capture in place:
shotscribe rename "~/Desktop/Screenshot 2026-08-11 at 3.41.07 PM.png"

# See what it WOULD do, without moving anything:
shotscribe rename --dry-run "~/Desktop/Screenshot ....png"

# Watch a folder and rename new captures as they land
# (defaults to your macOS screenshot location):
shotscribe watch
shotscribe watch ~/Pictures/Screenshots

# Skip Claude, use the offline keyword titler:
shotscribe label --no-claude "~/Desktop/Screenshot ....png"
```

## MCP server (Claude Code / Cowork integration)

`shotscribe-mcp` speaks MCP over stdio and exposes three tools:

| Tool | What it does |
|---|---|
| `latest_screenshots` | List the newest captures from your macOS screenshot folder |
| `ocr_screenshot` | On-device OCR — returns the text (+ an offline suggested title) so the *calling model* composes the label |
| `rename_screenshot` | Safe rename to `<date> <time> <Label>.ext`; takes the caller's `title`, protects user-named files (`force` to override), supports `dry_run` |

Register it with Claude Code:

```bash
swift build -c release
claude mcp add shotscribe -- "$(pwd)/.build/release/shotscribe-mcp"
```

Then, mid-session: *"grab my latest screenshot and give it a proper name"* —
Claude lists, OCRs, composes the title, renames. No nested LLM calls: when the
caller is already a model, the server stays mechanical.

## Menu bar app

`ShotScribe.app` is the always-there face: a menu bar panel with an
auto-rename watch toggle, a **configurable watch folder** ("Change…" — defaults
to your macOS screenshot location), a Claude/offline titler switch, **launch at
login**, "Rename latest capture now", and a history of recent renames. First
launch (and relaunching from Spotlight) shows a welcome window pointing at the
menu bar — a menu-bar-only app should never look like "nothing happened."
Activity logs to `~/Library/Logs/ShotScribe.log`.

```bash
./scripts/package-app.sh     # → dist/ShotScribe.app (ad-hoc signed, no Dock icon)
open dist/ShotScribe.app
```

Auto-rename is ON by default — launching an app whose one job is renaming
screenshots is the opt-in; the toggle is right there in the panel.

## Privacy

OCR runs entirely on-device (Apple Vision). Only the *extracted text* is sent
to the titler — and with `--no-claude`, nothing leaves the machine at all. With
the default `ClaudeTitler`, that text is sent to `claude -p` (which runs
inference on Anthropic's servers, billed to your Claude subscription).

## Roadmap

- [x] Core engine + CLI (`rename` / `label` / `watch`)
- [x] MCP server target (`shotscribe-mcp`) — Claude Code / Cowork call it as tools
- [x] `MenuBarExtra` app — the always-there local UI (`scripts/package-app.sh`)
- [x] App icon, welcome window, configurable folder, launch at login
- [ ] Backlog sweep — rename captures that landed while the app wasn't running
- [ ] WidgetKit widget — a one-tap App Intent front door
- [ ] Notarized distribution

## Why this exists

Extracted from a larger app ("Navi") as its own tool, on the theory that a
handful of small, sharp, open-source tools beats one monolith — each easy to
understand, iterate, and hand to Claude as a capability.
