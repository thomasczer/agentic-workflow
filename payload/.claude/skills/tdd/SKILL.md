---
name: tdd
description: Implement the current task test-first (red → green → refactor). Use for business logic and security boundaries once a plan has been approved.
---

Implement the current task using strict TDD. For each unit of behavior:

1. **RED** — write the smallest failing test that expresses the desired behavior. Run it and show me it fails for the _right_ reason. In a compiled or type-checked stack, a test that fails only because the module does not exist yet (compile or import error) has not shown that its assertions can fail: either stub the function first so the failure is an assertion, or, once green, break the implementation on purpose (flip a boundary, drop a branch) and show that a test goes red, then restore it.
2. **GREEN** — write the minimal code to make it pass. Run the test.
3. **REFACTOR** — clean up while keeping the bar green.

Prioritize tests for business logic and security boundaries (authorization, input validation, money/quantity computation, external-callback handling). Do not test trivial glue.

Never move to the next behavior with a red bar. Show real test output at each step — no "it should pass" without running it. When a test fails unexpectedly, find out whether the test or the code is wrong before touching either.

Commit the red test (`test:`) before the implementation that greens it (`feat:` / `fix:`) when the project's git discipline asks for it.

**Next — do not stop, do not ask.** You run inside the `implementer` agent dispatched by `/start-feature`: when your task is done and the bar is green, commit and end with the report the agent asks for (files and lines, tests and their output, anything the plan asked for that you could not do, and why). The orchestrator runs `/verify-slice` and the reviewers; a plan task that flags a load-bearing artifact is built and reported **alone first**, before anything is built on it (design checkpoint).
