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

No Claude Code plugin needed — skills, three subagents, hooks and settings are all native. On the machine: `bash`, `git`, `jq` or `python3` (hooks), `gh` authenticated (PRs, merge checks), and [`mise`](https://mise.jdx.dev), assumed present as the one handler for every runtime and dev tool: projects pin their toolchain in a committed `mise.toml`.

**Trust model.** Everything installed runs with the rights of the project that contains it, like any Claude Code hook: the hooks in `.claude/settings.json`, the test command the red-bar gate reads from `.claude/hooks/gate-tests.cmd`, and the formatter the format hook takes from the project's own `node_modules`. The toolkit adds no boundary beyond Claude Code's workspace trust: only bootstrap a repository you would run `npm install` in, and the git guard is a guardrail for the agent, not a security control (its header lists what it does not catch).

## The loop it installs

| Step | Command          | Guarantee                                                                                                                                                                                                                                                                                                                                                                                          |
| ---- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0    | `/start-feature` | One thin orchestration session per slice (on `opus` at `high` effort, the project's default settings): merge gate, branch, then each gate below in **its own fresh context, on the model that fits it** (plan and security review on the best model, verification on the cheapest), the four stops relayed to you. The orchestrator never runs the app driver, a build or a long tool loop itself. |
| 1    | `/plan-feature`  | Short plan in `docs/plans/`: loop size, testable acceptance criteria, files and patterns, out-of-scope, tests-first list, final end-to-end check. **Stop 1: your approval.**                                                                                                                                                                                                                       |
| 2    | `/tdd`           | One `implementer` agent per plan task: red for the right reason → green → refactor, real test output at each step; a `SubagentStop` hook runs the project's tests and sends the agent back while they are red. **Stop 2, when there is one: a design checkpoint.**                                                                                                                                 |
| 3    | `/verify-slice`  | Typecheck, lint, tests, **the real flow exercised**, and each acceptance criterion mapped to pasted evidence. The reviewers start at the same time.                                                                                                                                                                                                                                                |
| 4    | `/review-diff`   | Read-only reviewers with a **fresh context**, in parallel: the diff against the plan, and security. Confirmed findings are fixed test-first and reported. **Stop 3: a finding that changes scope, or could not be confirmed.**                                                                                                                                                                     |
| 5    | PR per slice     | Branch `feat/<NN>-<name>` from main, conventional commits, PR template. Commits on main and branches stacked on a slice are **blocked by a hook**, not by a promise.                                                                                                                                                                                                                               |
| 6    | Merge gate       | **Stop 4.** Opening the PR ends the slice: no next branch or plan until you say it is merged; then `MERGED` is checked and the next branch starts from the updated main.                                                                                                                                                                                                                           |

Between two stops the agent chains the steps itself — you are not asked whether to run the next one — and it does not idle while you read a plan or while reviewers run. The loop comes in two sizes, declared in each plan: **full** (authentication, money, data integrity, load-bearing artifacts — a plan of at most ~150 lines, both reviewers) and **light** (everything else — a one-screen plan, one reviewer). Trivial changes skip the ceremony altogether (one-sentence diff → branch, change, verify, PR). Contexts are per gate, not per project: `plan-feature` and `verify-slice` are forked skills (`context: fork`, their own `model`), `tdd` runs in `implementer` agents, the reviewers are agents; only their reports reach the orchestrator, and only it talks to you. `CLAUDE.md` is loaded by every one of them, so it stays short (everyday commands, conventions, the four stops; the loop and the model table live in the `start-feature` skill, loaded only where needed).

Plus **design checkpoints**: load-bearing artifacts (schema, API contract, auth model) are presented and validated before anything is built on them.

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
