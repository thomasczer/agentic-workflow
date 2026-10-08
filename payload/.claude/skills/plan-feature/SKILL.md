---
name: plan-feature
description: Plan a feature or slice before any implementation and write a short, capped plan to docs/plans/ (one screen for a light slice). Use at the start of every non-trivial slice, from /start-feature; runs in its own context on the best model the account has and returns the plan, its open questions and its decisions for the orchestrator's Stop 1 (the user's approval).
argument-hint: <feature name / short description>
context: fork
model: best
---

We are planning: $ARGUMENTS

You run in your own context, on the slice's branch (`/start-feature` has passed the merge gate and created it; check `git status -sb`), and you cannot talk to the user: whatever needs an answer goes in your final report, the orchestrator asks and sends the answers back to you.

**Outcome:** a plan at `docs/plans/<NN>-<kebab-name>.md`, committed on the slice branch (`docs: plan slice <NN>`), that a session which has read nothing but `CLAUDE.md` and the plan can execute — and that the user can read in two minutes: a plan approved unread protects nothing. No implementation code and no test made green: that is the implementer's job, after approval.

**What the plan holds**, within its size:

- Its second line: `Loop: full — <reason>` or `Loop: light — <reason>`. _Full_ when the slice touches authentication or authorization, money or quantities, data integrity (schema, migration, deletion), an inbound callback, or a load-bearing artifact; _light_ otherwise. Same gates either way, different weight: a light plan is one screen (**at most ~60 lines**) and its review is the `slice-reviewer` alone; a full plan is **at most ~150 lines** and gets both reviewers. The user can overrule the size when approving.
- The goal in one sentence and the **acceptance criteria** as observable, checkable statements ("when X, the system does Y"), not intentions. A goal that touches the "Won't" list of `SCOPE_PLAN.md` is flagged, not planned around.
- The modules and interfaces to create or modify, data-model touchpoints, how mutations happen, input validation, the authorization checks — following this project's conventions (`CLAUDE.md`) and, where the codebase already has a pattern for it, naming the file to imitate ("follow the pattern in `<path>`"). An explicit out-of-scope for this slice.
- Security: who is allowed to do this, what is validated server-side. For **every piece of state the slice adds or moves** — a cache, a store, a cookie, a file, a URL parameter, a background job — what clears it when the user logs out, is logged out, or is replaced by another user on the same device. "Nothing new" is only an answer after looking.
- Every **load-bearing artifact** the slice introduces: schema, migration, API contract, auth model — and their client-side equivalents: state that outlives a screen or a session, a route or URL contract, the module every request goes through. "None" needs a reason. Each gets a design checkpoint: built and validated before anything is built on it.
- The tests to write first, edge cases included.
- An ordered, checkable task list, each step with a verifiable outcome; tasks that do not depend on each other are marked as such, so they can be built in parallel (one implementer per worktree) when the slice is large enough for it to pay. A final **end-to-end verification step**: how the working feature will be demonstrated.

What does not belong in it: results of version probes beyond the one line that changes the design, full type signatures and contracts (they go in the code, or in the design checkpoint when there is one), the verification script written out command by command, notes for other teams (the project keeps those in one running file, not in every plan).

**How you get there.** Explore the relevant code before proposing anything — the project's `Explore` agent for broad exploration (read-only, on `haiku`: it locates and quotes, you judge), so it does not fill this context and does not run on this context's model; dispatch independent questions to several of them in one message. What an agent reports is a lead, not a fact: anything you copy from it into the plan (a status code, an ordering, a number, a file path) you re-check at the source. A library or framework version not yet used in this repo: check its installed version and read its bundled or official docs rather than relying on memory. Questions: only those that materially change the design and are not answerable from `CLAUDE.md`, `SCOPE_PLAN.md` or the codebase; each is a choice between options with trade-offs, recommended option first; until it is answered, plan under the recommendation and say so.

**Your final report** is what the orchestrator shows the user for Stop 1, so it holds, in this order and nothing else: the plan path; the loop size and its reason; the goal and the acceptance criteria; the open questions (options, trade-offs, recommendation); what you decided on your own; the load-bearing artifacts that will get a design checkpoint. No narration of your exploration. When the orchestrator sends answers back, revise the plan, commit (`docs: plan slice <NN>, questions answered`), and report the same way.
