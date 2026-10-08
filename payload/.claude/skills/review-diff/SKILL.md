---
name: review-diff
description: Adversarial review of the pending changes by fresh-context reviewers running in parallel (diff against the plan, and security), started automatically once the implementation is finished. Confirmed correctness / security / plan-conformance findings are fixed test-first and reported; anything that changes scope, a decision or visible behaviour waits for the user.
---

The session that wrote the code must not be the one grading it.

1. Determine the range — the **whole slice**, whatever state it is in: `git diff $(git merge-base HEAD main)` (no `...HEAD`: comparing the merge base to the working tree covers the branch's commits, staged changes and unstaged changes in one diff). Do not use a bare `git diff`: it shows unstaged changes only, so it misses everything already staged or committed on the branch — typical mid-TDD, once the red test is committed. **No diff shows untracked files**, and in a new slice most of the work is untracked: run `git status --short` and add every untracked file (`??`) that belongs to the slice to the range, as an explicit list of paths to read in full. Identify the slice's plan in `docs/plans/`.
2. Dispatch the reviewers **in one message, so they run in parallel**, each in its own fresh context, with **only** the range (the diff command above + the list of untracked files) and the plan path — not your reasoning, not a summary of what you did:
   - `slice-reviewer` — always; its definition runs it on `opus`, and on a `Loop: full` slice you dispatch it with the call parameter `model: fable` (the best model the account has; see the model table in `/start-feature`);
   - `security-reviewer` — on a full-loop slice (see the plan's "Loop" line), **and whenever the diff itself touches authentication, authorization, the session, or state that outlives a screen or a request, whatever the Loop line says** (look at the diff, not at the plan's opinion of it). Otherwise the `slice-reviewer`'s own security pass is the security review.

   Do not wait idle: while they run, `/verify-slice` runs in its own context (dispatched in the same message by `/start-feature`), and a Sonnet subagent drafts the PR body and the log entries if the project keeps a log. If an agent type is unavailable, use any fresh-context subagent with the instructions from `.claude/agents/<name>.md`; as a last resort, do the review yourself following that file, and say the review was not independent. The harness's built-in `/security-review` stays available on demand; the loop uses the agent because it runs in parallel, in its own context.

3. For a bug-hunting second opinion on a risky diff (payments, auth, migrations, concurrency), add the harness's built-in reviewer to the same message if there is one (Claude Code: `/code-review`; the `pr-review-toolkit` agents `silent-failure-hunter` and `code-reviewer` if installed).
4. Validate every returned finding against the actual code — open the file, read the lines, reproduce the scenario when it is cheap. Drop what doesn't hold; say what you dropped and why.
5. Sort the surviving findings:
   - **Apply without asking** — findings you have confirmed in the code **and** that concern correctness, security, or conformance to the approved plan, and whose fix stays inside the plan's scope. Fix them test-first (one `implementer` agent per finding or per file), then list each one in your report and in the PR: `file:line`, the failure scenario, what was changed, the test that now covers it.
   - **Stop and ask** — anything whose fix would change the scope, a decision recorded in `docs/decisions.md` or the plan, user-visible behaviour or copy, a load-bearing artifact, or that you could not confirm. Present these most severe first, each with `file:line`, a concrete failure scenario (inputs → wrong outcome) and a proposed fix, and wait.
   - A finding that fits both of the above is a **stop and ask**.
   - **Optional** — a reviewer asked to find gaps will always find some: anything that does not affect correctness, security, or the plan's requirements is listed separately, not applied and not asked about.
6. After fixes, re-run `/verify-slice` on what changed — a fix is a change like any other — and have the delta reviewed if it is more than a few lines.

**Next — do not stop unless step 5 produced a "stop and ask".** Log the slice if the project keeps a log, open the pull request, and stop there: the merge is the user's.
