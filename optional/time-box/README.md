# Optional module — Time box

Install **only** when the project has a duration the work must fit in — a stated budget, a deadline the work stops at — or when the user asks for it. A long-lived repository has no clock.

What it adds to the target project:

- `.claude/scripts/slice-clock.sh` → the wall clock. Reads **T0** and **Limit** from `SCOPE_PLAN.md` and prints elapsed, remaining, the stop time, how long the current slice has run (since the previous merge on the default branch, or since T0) and the projection from the budget table. Informational, always exits 0; without a T0 it says so.

When installed, the bootstrapping agent must also:

1. In Phase 3, **ask whether the duration is a hard limit** (the work stops at the stop time and what is merged ships) or a soft one (an overrun is acceptable if it is announced with numbers) — never assume, and never present scopes that exceed the duration as equal options: say by how much each one exceeds it. Estimates are wall-clock per slice, loop included: on the first measured project the non-build share was 20–55 min per slice, against 5–17 min of build.
2. Add the **Time budget** section below to `SCOPE_PLAN.md`, after the priorities. T0 is set when the first slice starts, from the machine clock (`date '+%F %H:%M'`), never from memory.
3. Add the **clock paragraph** below to the "How to work with me" section of the project's `CLAUDE.md`; it is what makes the orchestrator and the planner read the clock, since the core skills know nothing of it.
4. Add the **Time spent** section below to the project's `README.md`.
5. Order the slices so that a stop at the limit removes nothing that must ship: run instructions, the account of what was cut, the documents the spec requires go in early slices or are kept true by every slice, never in a last slice a stop time could remove. A time-boxed project can be stopped at any merge.
6. With the `ai-usage-log` module: a time entry is the pasted output of the clock plus the slice's estimate.

## Clock paragraph — `CLAUDE.md`, section "How to work with me"

```markdown
The clock: time is wall-clock since the **T0** of `SCOPE_PLAN.md`, read with `bash .claude/scripts/slice-clock.sh` and pasted as printed, never estimated. The orchestrator runs it at the start of every slice, before planning, and passes its output to `/plan-feature` with the slice: a slice whose estimate does not fit in what remains is cut first, with the numbers, and the planner says so at the top of its report. A slice estimated over ~30 min is a `Loop: full`. The orchestrator runs it again before opening the PR and fills the slice's "Measured" cell in `SCOPE_PLAN.md`; the checkpoint rule there applies, and what is measured is never redefined without asking me.
```

## Time budget section — `SCOPE_PLAN.md`, after the priorities

```markdown
## Time budget

- **T0**: <YYYY-MM-DD HH:MM — set at the start of slice 00>
- **Limit**: <N> min (<hard | soft>)

| #   | Slice                                        | Loop (full / light) | Estimate (min) | Measured (min) | Cumulative measured / limit |
| --- | -------------------------------------------- | ------------------- | -------------- | -------------- | --------------------------- |
| 00  | Scaffold, commands, README that already runs | light               | …              |                |                             |
| …   | …                                            | …                   | …              |                |                             |
|     | Buffer                                       |                     | …              |                |                             |

**Checkpoint rule.** At the start and at the end of every slice the agent runs `bash .claude/scripts/slice-clock.sh`, pastes its output, and fills "Measured" with the slice's wall-clock as printed (at the end of the slice, corrected at the start of the next one so that the merge wait is in it) — everything counts, nothing is excluded, and what is measured is never redefined along the way. The script prints the projection itself, from this table: elapsed + the estimates of the slices not measured yet × (measured so far ÷ estimated so far) — do not compute another one by hand. If the projection passes the limit, the agent proposes a cut **before anything else**, with the numbers, following the cut order below; with a hard limit, a slice that cannot finish before the stop time is not started.

**Cut order** — cheapest loss first, agreed in advance:

1. …
```

The estimate of a slice is wall-clock for the whole slice: planning, waiting for approvals, build, verification, reviews, fixes, the PR and the merge. The sum must fit the limit with a buffer; if it does not, cut scope now.

## Time spent section — `README.md`

```markdown
## Time spent

<!-- Wall-clock from T0, as printed by .claude/scripts/slice-clock.sh, against the limit. One figure, no exclusions. -->
```

Install: `bash <toolkit>/install.sh <project> --with time-box`
