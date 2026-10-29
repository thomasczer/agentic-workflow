# agentic-workflow

A portable, stack-agnostic workflow for building software with a coding agent (Claude Code first; the instructions are plain Markdown, so other harnesses can follow them too).

> **Coding agent?** Read [`BOOTSTRAP.md`](BOOTSTRAP.md) and follow it. Do not modify this repo.

## Use it

In a new or existing project directory, start the agent and say:

```text
Bootstrap this project with https://github.com/thomasczer/agentic-workflow
```

The agent clones this repo to a temp dir, installs the workflow into the project, drafts `SCOPE_PLAN.md` with you (it stops for your decisions), writes a project-specific `CLAUDE.md` with commands it has actually run, smoke-tests the setup, and makes the baseline commit. Everything is **vendored** into the project — no runtime dependency on this repo, and anyone cloning the project gets the workflow with it.

## Requirements

No Claude Code plugin needed — skills, four subagents, hooks and settings are all native. Some plugins compete with the loop (`superpowers`, `feature-dev`, `ralph-loop`, `security-guidance`: their own planning, build or review process, or hooks that restart work): the bootstrap lists the ones enabled and offers to switch them off in the project only. Others complement it over a project's life, and the bootstrap suggests them without installing them: at the handover, `claude-security` (a scan of the whole codebase, where the loop's reviewer sees one diff), `session-report` (what each gate costs) and `project-artifact` (a status page for whoever follows the project); before scoping a legacy codebase, `code-modernization`. On the machine: `bash`, `git`, `jq` or `python3` (hooks), `gh` authenticated (PRs, merge checks), and [`mise`](https://mise.jdx.dev), assumed present as the one handler for every runtime and dev tool: projects pin their toolchain in a committed `mise.toml`.

**Trust model.** Everything installed runs with the rights of the project that contains it, like any Claude Code hook: the hooks in `.claude/settings.json`, the test command the implementer's test gate reads from `.claude/hooks/gate-tests.cmd`, and the formatter the format hook takes from the project's own `node_modules`. The toolkit adds no boundary beyond Claude Code's workspace trust: only bootstrap a repository you would run `npm install` in, and the git guard is a guardrail for the agent, not a security control (its header lists what it does not catch).

## The loop it installs

| Step | Command           | Guarantee                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ---- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0    | `/start-feature`  | One thin orchestration session per slice (on `opus` at `high` effort, the project's default settings): merge gate, branch, then each gate below in **its own fresh context, on the model that fits it** (plan and security review on the best model, the full check on `sonnet`, reading on `haiku`), the four stops relayed to you. The orchestrator never runs the app driver, a build or a long tool loop itself.                                                                                                                                       |
| 1    | `/plan-feature`   | Short plan in `docs/plans/`: loop size, testable acceptance criteria, files and patterns, out-of-scope, the tests of each task and their level (the slice's test budget), final end-to-end task. **Stop 1: your approval.**                                                                                                                                                                                                                                                                                                                                |
| 2    | `/implement-task` | One `implementer` agent per plan task, one after the other on the slice branch: the task designed whole, coded, pinned by the tests the plan assigns to it (one per scenario, unit tests for pure logic only), each shown able to fail by breaking the code once; a `SubagentStop` hook runs the tests covering the change and sends the agent back while they are red; the agent plays its e2e spec by name and **exercises the real flow**. A bug fix alone starts with the test that reproduces it. **Stop 2, when there is one: a design checkpoint.** |
| 3    | Full check        | Once per slice, by a `sonnet` subagent, in parallel with the reviewers: typecheck, lint, the whole test suite — what the CI checks — and the suite's time against its budget. The only full run before the CI, since each task was proven by its implementer.                                                                                                                                                                                                                                                                                              |
| 4    | `/review-diff`    | Read-only reviewers with a **fresh context**, in parallel: the diff against the plan, and security. Confirmed findings are fixed (reproducing test first) and reported. **Stop 3: a finding that changes scope, or could not be confirmed.**                                                                                                                                                                                                                                                                                                               |
| 5    | PR per slice      | Branch `feat/<NN>-<name>` from main, conventional commits, PR template. Commits on main and branches stacked on a slice are **blocked by a hook**, not by a promise.                                                                                                                                                                                                                                                                                                                                                                                       |
| 6    | Merge gate        | **Stop 4.** Opening the PR ends the slice: no next branch or plan until you say it is merged; then `MERGED` is checked and the next branch starts from the updated main.                                                                                                                                                                                                                                                                                                                                                                                   |

Between two stops the agent chains the steps itself — you are not asked whether to run the next one — and the reviewers and the full check run at the same time; at a stop it waits and runs nothing on the side. The loop comes in two sizes, declared in each plan: **full** (authentication, money, data integrity, load-bearing artifacts — a plan of at most ~150 lines, both reviewers) and **light** (everything else — a one-screen plan, one reviewer). Trivial changes skip the ceremony altogether (one-sentence diff → branch, change, the tests covering it, PR). Contexts are per gate, not per project: `plan-feature` is a forked skill (`context: fork`, its own `model`), `implement-task` runs in `implementer` agents, the reviewers are agents, the full check is a subagent; only their reports reach the orchestrator, and only it talks to you. `CLAUDE.md` is loaded by every one of them, so it stays short (everyday commands, conventions, the four stops; the loop and the model table live in the `start-feature` skill, loaded only where needed).

Plus **design checkpoints**: load-bearing artifacts (schema, API contract, auth model) are presented and validated before anything is built on them.

**Why the task is built whole, not test-first.** TDD inside an agent's own loop has measured no quality gain for several times the tokens ([Böckeler, 2026](https://martinfowler.com/articles/exploring-gen-ai/tdd-in-the-agent-loop.html)): the agent fakes or skips the red, and the design that emerges one test at a time is never revisited; meanwhile the suite it grows, two lines of test per line of code, saturates a CI within days. The human checkpoint TDD relied on is Stop 1, where the scenarios of each task are approved; the proof that a test can fail is the break-and-restore check; the brake on volume is a time budget and a reviewer that deletes. The red stays where it has measured value: a bug fix starts with the test that reproduces it.

The orchestrator's model is checked by a hook too: `/start-feature` is **blocked** in a session that runs on another model than the one the table gives it (`opus`). Interactive sessions report their model to the hook; headless ones (`claude -p`) do not, so there the hook reads the `--model` flag or `ANTHROPIC_MODEL`, and a model set only in a settings file gets a note, not a block. A `/model` switch during the slice cannot be blocked, but the hook records it and tells the orchestrator, which stops for your word.

## Layout

```text
BOOTSTRAP.md   the procedure the agent follows (the heart of this repo)
install.sh     no-clobber copy of payload/ (+ optional modules) into a target
payload/       copied verbatim: .claude/{skills,agents,hooks}, settings.json, PR template, docs/plans
tests/         checks for the toolkit itself (guard-git command matrix)
templates/     filled in during bootstrap: CLAUDE.md, SCOPE_PLAN.md, README.md
optional/      opt-in modules — time-box (slice clock + budget contract) for projects with a deadline, ai-usage-log (/log-decision + AI_WORKFLOW writeup) for projects that require it
```

Manual install, without an agent: `bash install.sh /path/to/project [--with time-box] [--with ai-usage-log]`, then fill the templates yourself.

## Evolving it

When a project teaches you something (a skill step that was missing, a guardrail that would have caught a bug), port the improvement back here so the next project starts with it — as a pull request: one commit per fix, the observed failure in the description, what was verified and what could not be. This repo applies its own guard (`.claude/settings.json` wires `payload/.claude/hooks/guard-git.sh`): no commits on main.

Already-bootstrapped projects pick improvements up by asking the agent to _update_ from this URL (see the last section of `BOOTSTRAP.md`).

## License

[MIT](LICENSE).
