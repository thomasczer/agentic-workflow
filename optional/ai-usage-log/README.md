# Optional module — AI usage log

Install **only** when the project spec asks for an account of how AI was used (an `AI_WORKFLOW.md`-style deliverable), or when the user asks for it.

What it adds to the target project:

- `/log-decision` skill → appends accept / change / reject entries to `AI_SESSION_LOG.md`.

When installed, the bootstrapping agent must also:

1. Add a step to the per-slice workflow in the project's `CLAUDE.md`, after `/review-diff`:
   `` `/log-decision` — end-of-slice sweep; also log notable accept/change/reject moments as they happen. ``
2. Add `AI_WORKFLOW.md` (final writeup, from the log, the plans and the PR history — the agent supplies the raw facts from the record; **nothing is drafted in the user's voice before asking**: opinions, lessons and first-person statements are proposed as a short list the user accepts, strikes or rewrites, and a section the user does not want to write says what the record shows and no more) to the deliverables in `SCOPE_PLAN.md`. Suggested sections: Tools · How the work was prompted/planned · Accepted / changed / rejected · Where the guardrails caught real bugs · Manual review · What I'd improve with more time.

Install: `bash <toolkit>/install.sh <project> --with ai-usage-log`
