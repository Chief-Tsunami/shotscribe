# Hook

Working rules for this repo, per CHRIS OP (`~/.claude/CHRIS-OP.md`).

## Progress rule
As work happens, `Context.md`, `History.md`, and `roadmap.md` get updated
to reflect it. `/save` is the checkpoint gesture — run it to bring all
three back in sync with the repo's actual state.

## Push rule
**Pushing is user-authorised only.** `~/.git-hooks/pre-push` blocks pushes from
`~/git/personal` and `~/git/work` unless `MANUAL_PUSH=1`. It is a gate rather
than a guideline because the rule it replaces — "at 10 changes, commit and push"
— was written in twelve files and out-voted every spoken "local only" (2026-08-25:
100 of 103 commits across these repos were assistant-pushed).

Commit locally and freely; local commits are cheap and make history bisectable.
**Push once at end of day, or when asked.** A soft reminder late in the day is
welcome. An automatic push is not.

## Roadmap rule
`roadmap.md` is **local planning only and never gets committed.** It lives at
the repo root, lowercase, with `/roadmap.md` in `.gitignore`. It reads as noise
to anyone reviewing the project, and staying untracked keeps it out of review. If it ever shows up staged
or tracked, stop and fix that before anything else.

## Phase rule
`Phase.md` is maintained by `/save`, not only at `/close`. Mid-session is when
phase state actually changes and when it is cheapest to record: tick off gate
items as they complete, and write down sub-issues **the moment they surface**.
A discovered blocker is the most expensive thing to reconstruct later. The
phase line itself moves only when a gate genuinely clears.
