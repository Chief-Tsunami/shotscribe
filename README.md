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

## The "connect to Claude" part

Titling is a swappable seam (`Titler`):

- **`ClaudeTitler`** shells out to the local [Claude Code](https://claude.com/claude-code)
  CLI (`claude -p`), sandboxed (no tools, no MCP) since the prompt carries text
  pulled off your screen. This is the default when `claude` is installed.
- **`KeywordTitler`** needs no network and no Claude — it picks the salient words
  straight from the OCR text. So the tool is still useful to anyone.

Because titling is one file behind a protocol, the *same core* can later be
driven by an **MCP server** — so Claude Cloud / Cowork can call
`label_screenshot` as a tool during a terminal session, instead of the tool
calling Claude. That inversion is the roadmap below.

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

## Privacy

OCR runs entirely on-device (Apple Vision). Only the *extracted text* is sent
to the titler — and with `--no-claude`, nothing leaves the machine at all. With
the default `ClaudeTitler`, that text is sent to `claude -p` (which runs
inference on Anthropic's servers, billed to your Claude subscription).

## Roadmap

- [x] Core engine + CLI (`rename` / `label` / `watch`)
- [ ] MCP server target — expose `label_screenshot` so Claude Cloud / Cowork can call it
- [ ] `MenuBarExtra` app — the always-there local UI
- [ ] WidgetKit widget — a one-tap App Intent front door

## Why this exists

Extracted from a larger app ("Navi") as its own tool, on the theory that a
handful of small, sharp, open-source tools beats one monolith — each easy to
understand, iterate, and hand to Claude as a capability.
