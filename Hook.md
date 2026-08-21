# Hook

Working rules for this repo, per CHRIS OP (`~/.claude/CHRIS-OP.md`).

## Progress rule
As work happens, `Context.md`, `History.md`, and `roadmap.md` get updated
to reflect it. `/save` is the checkpoint gesture — run it to bring all
three back in sync with the repo's actual state.

## Push rule
Never accumulate more than **10 changes** (file edits since the last push).
At 10, stop, commit meaningfully, and push. Working tree was clean at audit
time (2026-08-12), HEAD at `9d2c9a2`.

## Roadmap rule
`roadmap.md` is **local planning only and never gets committed.** It lives at
the repo root, lowercase, with `/roadmap.md` in `.gitignore`. It reads as noise
to anyone reviewing the project, and staying untracked also keeps roadmap churn
from counting toward the 10-change push threshold. If it ever shows up staged
or tracked, stop and fix that before anything else.

## Phase rule
`Phase.md` is maintained by `/save`, not only at `/close`. Mid-session is when
phase state actually changes and when it is cheapest to record: tick off gate
items as they complete, and write down sub-issues **the moment they surface**.
A discovered blocker is the most expensive thing to reconstruct later. The
phase line itself moves only when a gate genuinely clears.
