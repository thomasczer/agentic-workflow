---
name: verify-slice
description: Evidence gate before claiming a slice (or any change) works — typecheck, lint, tests, the real behavior exercised, and each acceptance criterion mapped to proof, with pasted output. Use when the implementation is finished, again after review fixes, and before opening the PR. Runs in its own Sonnet context and returns an evidence report.
argument-hint: <plan path, or "delta: <what changed>" on a re-run>
context: fork
model: sonnet
---

Slice or delta to verify: $ARGUMENTS. You run in your own context; the orchestrator reads only your final report, so it must stand alone.

Do NOT claim this works until you have shown evidence. Run each step and paste the real output. (Between two commits of the same slice, steps 1–3 are enough; the full gate is for "this slice is done".)

1. The project's typecheck / static-analysis command (see CLAUDE.md "Commands"; skip only if the stack has none, and say so)
2. The project's lint command
3. The tests covering this change
4. **Exercise the actual flow** — drive the UI / hit the endpoint / run the CLI and observe the result (screenshot the page, show the HTTP response, show the created DB row or output). "It compiles" and "tests pass" are not this step.
   - **Use the project's own driver** — the e2e tool or script folder set up in slice 00 (see `CLAUDE.md` "Commands") — and extend it with this slice's flow instead of improvising a throw-away script: what you drive today is replayed by the next slice. If the harness ships an app-driving skill you can invoke (Claude Code's bundled `/run`; its `/verify` runs only when the user types it, since v2.1.215) or a browser tool, use it to look, not as the only record. A tool that drops mid-run is not a reason to skip the step: fall back to the project's driver.
   - **Processes**: start servers in the background with their output in a log file; stop them **by port or by PID** (`fuser -k <port>/tcp`, `kill <pid>`). Never `pkill -f <pattern>` / `killall`: a pattern wide enough to match your server matches the harness's own helpers. Leave nothing running when the slice ends.
   - What could not be exercised is reported as **not exercised**, with the reason — never as verified.
5. Walk the acceptance criteria of the slice's plan in `docs/plans/` one by one and state, for each, which evidence above proves it. An unproven criterion means the slice is not done.

If anything fails, fix it and re-run from step 1. Only when every step is green do you report done — and state exactly what you ran and what you observed.

**The README is part of the slice.** Its run instructions are replayed **from a clean state** (fresh clone in an empty directory / fresh containers / empty DB), following the README word for word, in slice 00 and again before final delivery — and whenever a slice changes how the project is installed or started. Anything you had to do that the README does not say is a defect of the README. Setup steps that were never re-run from scratch are assumed broken.

<!-- Named verify-slice, not verify: Claude Code's bundled /verify records its own recipe at .claude/skills/verify/SKILL.md and would overwrite a skill of that name. -->

**Your final report** — nothing else: one line per command with its exit status and the decisive lines of output (counts, failures, timings); the real flow exercised, with what was observed (and the path of every screenshot or log you kept); the table acceptance criterion → evidence; anything **not exercised**, with the reason; anything red, with the output. No claims without the output that backs them. Leave nothing running.
