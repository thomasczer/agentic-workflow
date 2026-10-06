---
name: log-decision
description: Append a timestamped accept/change/reject entry to AI_SESSION_LOG.md. Use at the end of each slice and whenever the user notably accepts, changes, or rejects AI output.
argument-hint: <what happened — accepted / changed / rejected AI output, or a decision>
---

Append a concise dated bullet to `AI_SESSION_LOG.md` (create the file if missing) capturing: $ARGUMENTS

First read the clock with a command (`date '+%F %H:%M %Z'`), as its own step, **before** composing the entry: the timestamp is what the machine said, never an estimate. Log at the moment the decision is made, not in a batch afterwards.

Time entries: with the `time-box` module installed, a time entry is the pasted output of `bash .claude/scripts/slice-clock.sh` plus the slice's estimate — wall-clock, everything included. Do not reconstruct durations from commit timestamps, and do not subtract planning or waiting time: a figure that excludes them hides exactly the overruns the clock exists to show.

Use this format:
`- [<date time>] <what the AI proposed> → <accepted | changed | rejected> because <the user's stated reason, or "no reason given">. Manual review: <what the user said they checked, or "none reported">.`

The entry is written in the third person and attributes nothing to the user that they did not say: no invented reason, no verification they did not report. What the agent itself ran or observed is recorded as the agent's, with how it was observed.

Keep it factual and short — this is raw material for a writeup of how AI was used, not prose. Do not embellish; if the AI got something wrong, say so plainly. A wrong entry that has already been pushed is corrected by a new entry, not by rewriting history.
