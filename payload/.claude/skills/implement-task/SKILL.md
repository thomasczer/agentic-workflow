---
name: implement-task
description: Build the current task of an approved plan whole — designed first, then coded, then pinned by the tests the plan assigns to it and no more — and prove those tests can fail. A bug fix alone starts with the test that reproduces it. Use inside the implementer agent, once a plan has been approved.
---

Build the task as one piece, then pin it.

1. **Design first.** Read the acceptance criteria and the scenarios the plan assigns to this task, and the file it names to imitate. Decide the shape of the whole task — types, interfaces, the edge cases the plan lists — before the first line of code: a design that emerges one test at a time is rarely revisited.
2. **Code it.** Implement the task whole. Run the project's typecheck and the tests that already exist on the paths you touch.
3. **Pin it.** Write the tests the plan lists for this task — one per scenario, at the level the plan says: the e2e spec, played by name, for a flow; a unit test only for pure logic (a computation, a parser, a decision at a security boundary); nothing for glue. No test the plan did not ask for without one line of reason in your report; no test that duplicates another; no test that asserts how the code is written (a mock called with these arguments, a helper called once) rather than what it does. Mock only at a process boundary (the network, the clock, the filesystem, an external program), never a module of this project.
4. **Prove they can fail.** Once green, break the implementation on purpose (flip a boundary, drop a branch, return a constant), show which test goes red, then restore it. A test that stays green through this is rewritten or deleted: a green bar nobody has seen red proves nothing.

A **bug fix** — a review finding, a red CI, an issue — is the one case that starts red: the test that reproduces it is written and shown failing first, committed as `test:`, then the `fix:` that greens it; two commits of one task.

Show real test output at every step — no "it should pass" without running it. Never end with a red bar: the tests covering your change pass before you stop (your stop hook runs them). When a test fails unexpectedly, find out whether the test or the code is wrong before touching either. The suite has a time budget (`CLAUDE.md` "Testing"): a task that takes it over removes tests before it adds any.

**Next — do not stop, do not ask.** You run inside the `implementer` agent dispatched by `/start-feature`: when your task is done and the bar is green, commit (`feat:` with its tests, one commit) and end with the report the agent asks for (files and lines, tests and their output, which test went red in the break-and-restore check, anything the plan asked for that you could not do, and why). The orchestrator runs the reviewers and the full check; a plan task that flags a load-bearing artifact is built and reported **alone first**, before anything is built on it (design checkpoint).
