---
description: slice-reviewer gives each finding its consequence and its evidence, ends with what it could not check, and still catches tests that cannot fail.
runs: 3
max_turns: 10
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Agent]
---

Dispatch the `agentic-workflow:slice-reviewer` agent (Agent tool) with exactly this input: "Diff of the slice: `git diff $(git merge-base HEAD main)`. Untracked files: none. Plan: `docs/plans/01-shipping.md`." Do not review yourself. Then give its report verbatim.
