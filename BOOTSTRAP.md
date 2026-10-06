# Bootstrap procedure — instructions for the coding agent

You are reading this because the user gave you this repository's URL and asked you to set up their project with it. This repo is a **toolkit**, not the project. Your job is to install its agentic workflow into the user's **target project** (your current working directory, unless told otherwise) and tailor it, so that every later session in that project follows the same disciplined loop:

> plan → _approval_ → TDD → verify with evidence, while fresh-context reviewers (diff against the plan, security) run in parallel → confirmed findings fixed → PR per slice → _the user merges_ → next slice from the updated main
>
> Four stops — plan approval, design checkpoint, a review finding that changes scope or could not be confirmed, the merge — and nothing else interrupts a slice.

Follow the phases in order. The **STOP** markers are real: end your turn and wait for the user.

## Ground rules

- Never modify, commit to, or push this toolkit repo. Work from a throwaway clone (`git clone <url> "$TMPDIR/agentic-workflow"`; read the files from the clone, not through a web fetch of the repository pages). Delete the clone at the end.
- Installed files are **vendored**: the target project must never depend on this repo at runtime. Anyone cloning the project gets the whole workflow with it.
- Never overwrite an existing file in the target. Merge, or ask.
- The user owns scope and design decisions. You draft, recommend, and explain trade-offs; they decide.
- Write project files in English unless the project spec or the user says otherwise. Talk to the user in their language.

## Phase 0 — Prerequisites

No Claude Code plugin is required: everything installed is native (skills, three subagents, hooks, settings), and the commands referenced (`/security-review`, `/code-review`, `/verify`, `/run`) ship with Claude Code.

Check the machine, and report anything missing to the user **before** going further — do not install system tools on your own initiative:

| Tool                 | Why                                                                           | If missing                                                                |
| -------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `bash`, `git`        | hooks, everything                                                             | stop                                                                      |
| `jq` or `python3`    | the hooks parse their JSON input with one of them                             | **stop**: without either, `guard-git.sh` silently lets everything through |
| `mise`               | assumed available; the single handler for every language runtime and dev tool | stop and ask — see below                                                  |
| `gh` (authenticated) | opening PRs, checking merges                                                  | ask the user how they want to proceed                                     |

**Runtimes go through `mise`, always.** Never install a language runtime or version manager another way (no nvm, pyenv, rustup-by-hand, system packages, `curl | sh`). Pin what the project needs in a committed `mise.toml` (`mise use node@22`, `mise use python@3.13`, …) so the environment is reproducible from the repo alone; CLI dev tools that mise can provide (formatters, linters, task runners) are pinned there too. If the shell running your commands is not mise-activated, prefix them with `mise exec --` (or `mise x --`).

## Phase 1 — Survey the target (read-only)

Establish, and summarize to the user in a few lines:

1. **Project spec** — the document describing what must be built (requirements, constraints, deliverables). Make no assumption about its name, format, or location, and do not go looking for it by guessing filenames. If the user's initial prompt already contains it or says where it is, use that. Otherwise **ask the user explicitly where it is** (a file path, a URL, or text they paste) and wait for the answer before going past this phase; "there is none, here is the goal in a few sentences" is a valid answer. Once you have it, read it in full and note the explicit deliverables, the hard constraints, and any duration or deadline — a project that has one is time-boxed: install the `time-box` module in Phase 2 and follow `optional/time-box/README.md`.
2. **State**: empty directory, fresh scaffold, or existing codebase? Is it a git repo, is there a remote, which branch?
3. **Stack**: imposed by the spec, already scaffolded, or still open? Note exact major versions of the main dependencies.
4. **Existing agent config**: `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.github/pull_request_template.md`. Anything present is merged with, never replaced.
5. **AI-usage deliverable**: does the spec require documenting how AI was used? If yes, you will install the optional `ai-usage-log` module (see `optional/ai-usage-log/README.md`). If not, don't.

## Phase 2 — Install the payload

```bash
bash <clone>/install.sh <target> [--with time-box] [--with ai-usage-log]
```

It copies, without clobbering:

| Installed path                                                        | Purpose                                                                                                                                                                                                                |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/skills/start-feature/SKILL.md`                               | The orchestrator of one slice: merge gate, branch, then each gate in its own context, the four stops relayed                                                                                                           |
| `.claude/skills/{plan-feature,tdd,verify-slice,review-diff}/SKILL.md` | The gates of the per-slice loop; `plan-feature` and `verify-slice` are forked skills (`context: fork`) with their own `model`                                                                                          |
| `.claude/agents/implementer.md`                                       | Builds one plan task test-first (`/tdd` preloaded), one agent per task, in a worktree when the task is independent                                                                                                     |
| `.claude/agents/slice-reviewer.md`                                    | Read-only, fresh-context reviewer dispatched by `/review-diff`: the diff against its plan                                                                                                                              |
| `.claude/agents/security-reviewer.md`                                 | Read-only, fresh-context security reviewer, dispatched in parallel with it on full-loop slices                                                                                                                         |
| `.claude/hooks/guard-git.sh`                                          | Blocking `PreToolUse` gate: no commit/push on main, no plain force-push, no branch stacked on a slice branch                                                                                                           |
| `.claude/hooks/format-edited-file.sh`                                 | Non-blocking format-on-edit hook                                                                                                                                                                                       |
| `.claude/hooks/orchestrator-check.sh`                                 | `SessionStart` records the session's model; `UserPromptSubmit` blocks `/start-feature` when that model is not the orchestrator's (`opus`, or `$ORCHESTRATOR_MODEL`)                                                    |
| `.claude/hooks/gate-tests.sh`                                         | `SubagentStop` gate of the `implementer` (declared in its frontmatter): runs the command named in `.claude/hooks/gate-tests.cmd` and blocks the agent from ending on a red bar; off until that file exists (slice 00)  |
| `.claude/settings.json`                                               | Starts every session on `opus` at `high` effort (`model`, `modelSettings`); wires the four hooks; denies reading `.env*` (except `.env.example`); `worktree.baseRef: head` so subagent worktrees branch from the slice |
| `.github/pull_request_template.md`                                    | PR structure: context → approach → trade-offs → security → review findings → verification                                                                                                                              |
| `docs/plans/README.md`                                                | Where `/plan-feature` writes plans                                                                                                                                                                                     |

Then:

- Resolve every reported **conflict** by merging by hand (typically `.claude/settings.json`: add the `model` and `modelSettings` keys, the `PreToolUse` / `PostToolUse` / `SessionStart` / `UserPromptSubmit` entries, the `permissions.deny` rules and the `worktree.baseRef` key to what exists; keep everything already there). `modelSettings` is keyed by the full model ID `opus` resolves to today (`claude-opus-5-5`): when the alias moves to a newer Opus, update the key. `worktree.baseRef: "head"` matters: without it a subagent worktree branches from `main`, not from the slice branch, so an `implementer` in a worktree would build without the plan and the tasks already merged.
- Trim `format-edited-file.sh` to the project's stack if you want, or leave it — missing formatters are silent no-ops. JS tools (Biome, else Prettier + ESLint) are taken from the `node_modules` nearest to the edited file, so an app nested in a sub-directory or a workspace is covered. If the stack's formatter isn't covered, add a branch.
- If the default branch is not `main`/`master`, adapt the `case` in `guard-git.sh`.
- The loop's security pass is the `security-reviewer` agent, because it runs in parallel with the diff review. Claude Code's built-in `/security-review` is not installed and stays available on demand, as a second opinion.
- **Models.** The skills and agents carry `model:` and `effort:` fields: `best` for the plan (Claude Code's alias: `fable` where the account has it, else `opus` — nothing to edit), `fable` for the security review, `opus` for the implementer and the diff review, `sonnet` for the verification. The `best` alias is documented for skills, not for agents: if the account has no `fable`, replace it by `opus` in `security-reviewer.md` and in the model table of `start-feature/SKILL.md` (the single source: `CLAUDE.md` only points to it). The orchestration session itself runs on `opus` at `high` effort, set as the project's defaults by `.claude/settings.json` (`model`, `modelSettings`) — no flag to type; `--model`, `--effort` and `ANTHROPIC_MODEL` still override them, which is what the orchestrator check (next commit's hook) catches. A skill or agent `model` field overrides the session model for that context.

## Phase 3 — Scope plan · **STOP for validation**

Create `SCOPE_PLAN.md` from `templates/SCOPE_PLAN.template.md`.

1. Summarize the project spec back to the user.
2. Identify the **scoping forks** — every place where the spec is ambiguous or where a real architectural/product choice exists (auth model, data model shape, payment/confirmation flow, delivery target, what to cut…). For each: options, trade-offs, your recommendation. **Where the code is hosted is always one of them**: a remote with real pull requests, or a local-only repository — it changes the workflow written in Phase 4 (see "Local-only projects"). Never create a remote or push without that decision.
3. Draft MoSCoW priorities, the decisions list, and the non-negotiables. Time-boxed project: add the time budget and ask whether the limit is hard or soft, as `optional/time-box/README.md` says.
4. **STOP.** Present the forks and the draft — one fork at a time through the harness's structured question tool when it has one (Claude Code: `AskUserQuestion`, recommended option first), free text otherwise. The user decides each fork; record the decision _and its justification_ in `SCOPE_PLAN.md`. Do not proceed on unvalidated scope.

Keep `SCOPE_PLAN.md` short: the one sentence, current priorities, out-of-scope, the decisions, non-negotiables.

## Phase 4 — Project instructions

Create `CLAUDE.md` from `templates/CLAUDE.template.md` (or merge its sections into an existing one).

- **Stack**: exact versions, matching `mise.toml`. For any dependency whose major version may postdate your training data, add a bold _version trap_ line pointing to the authoritative docs (bundled in the package when they exist) — and actually read them before writing code against it. Verify API assumptions by reading or running, never by guessing.
- **Commands**: every command must be one you have actually run successfully. If the project isn't scaffolded yet, write `n/a until slice 00` for each label — scaffolding is the first slice and goes through the normal loop, it is not part of the bootstrap — and make filling this section an explicit deliverable of that slice. Never write a command that was not run.
- **Conventions / Security / Testing priorities / Out of scope**: derive from `SCOPE_PLAN.md` and the codebase. Delete generic bullets that cannot apply to this project; add the project-specific ones (authz model, tenant isolation, money handling, idempotency keys…).
- The "How to work with me" section is the contract — keep it verbatim, adding the `/log-decision` step only if the optional module was installed. Nothing in it depends on the project; the `time-box` module adds its clock paragraph (see its README). The loop and the model table are not repeated here — they live in `.claude/skills/start-feature/SKILL.md`, which every context can read on demand, while this file is loaded into every context whether it needs them or not. The session hygiene is no longer a choice: one session per slice, opened by `/start-feature`, and every gate in its own forked context — a fresh context per gate costs the user nothing, time-boxed or not.
- No `<placeholder>` or `<!-- comment -->` may remain.
- **Keep it short** — it is loaded into every context (the orchestrator and every forked skill or subagent pay for it), and rules get ignored when the file is long. The "Commands" section holds the everyday commands only; the rest goes to `docs/commands.md`. For each line ask: would removing it cause a mistake? Anything the agent can read from the code goes; anything that must happen every time without exception belongs in a hook, not in prose; conventions that only concern one area of the code go to `.claude/rules/<topic>.md` with a `paths:` frontmatter so they load only when matching files are touched. Target well under 200 lines.

If the project must also work with other harnesses, make `AGENTS.md` the canonical file and have `CLAUDE.md` import it (`@AGENTS.md`), or the reverse — one source of truth, not two copies.

Create `README.md` from `templates/README.template.md` only if the project has no README. It is a skeleton for one slice at most: slice 00 makes its run instructions real (replayed on a clean clone), and every slice after that keeps it true — what is built, what was cut and why, what comes next. The repository must be shippable after every merge, not only after the last one.

## Phase 5 — Smoke test, with evidence

First make the target a git repository if it is not one (`git init -b main`), and make sure `.gitignore` ignores `.env*` and `.claude/settings.local.json` but not `.env.example` or `.claude/` (`.claude/agent-memory/`, where the reviewers keep this project's recurring pitfalls, is meant to be committed). The guard reads the current branch: outside a repository it lets everything through, so it cannot be tested there.

Hooks, permission rules, skills and subagents are read when a session starts. The session running this bootstrap started **before** they were installed, so it may not see them — testing from inside it proves little, and a test that "fails" here may only mean "restart needed". Test the wiring in a fresh session instead:

1. **Prerequisites**: show that `jq` or `python3` resolves (`command -v jq python3`). If neither does, the guard is inert — stop and tell the user.
2. **Wiring, in a fresh session.** With Claude Code, run a headless session from the target directory (create a throwaway `.env` containing a fake secret and a `.env.example` first; delete both after if you created them):

   ```bash
   claude -p 'Wiring test. Do exactly this, report raw results, no fixing, no retries, no workarounds:
   1. Run: git commit --allow-empty -m "wiring test" — did it run or was it blocked? Exact message.
   2. Read ./.env with the Read tool — allowed or refused?
   3. Read ./.env.example with the Read tool — allowed or refused?
   4. List the project skills and project subagents you can see (not plugins, not built-ins).' \
     --allowedTools "Bash(git commit *)" "Read"
   ```

   Expected: (1) **blocked** with the guard's message and `git log` unchanged, (2) refused, (3) allowed, (4) `start-feature`, `plan-feature`, `tdd`, `verify-slice`, `review-diff` + `implementer`, `slice-reviewer`, `security-reviewer`. Paste the output. If the commit went through, drop it (`git reset --soft HEAD~1`, or `git update-ref -d HEAD` if it was the repository's very first commit) and fix the wiring in `.claude/settings.json`.

   If no headless runner is available, call the hook scripts directly with a simulated payload to test their logic (`echo '{"cwd":"<target>","tool_input":{"command":"git commit -m x"}}' | bash .claude/hooks/guard-git.sh; echo $?` → 2 on main), say clearly that the **wiring itself is unverified**, and put "restart the session, then try `git commit --allow-empty -m test` on main — it must be blocked" at the top of the handover.

3. **Format hook**: call it on a throwaway, badly formatted file of the project's main language; show that it was reformatted, or state that no formatter is installed yet and the hook no-ops (normal before the scaffold slice). Remove the file.
4. **Commands**: run each entry of the `CLAUDE.md` "Commands" section that can run at this stage.

## Phase 6 — Baseline commit and handover

1. Make sure no smoke-test leftovers remain (throwaway files, a test commit).
2. Commit the bootstrap as the baseline: `chore: bootstrap agentic workflow (toolkit @ <revision printed by install.sh>)`. This is the **only** direct commit to main, so it needs the guard's escape hatch — `ALLOW_MAIN=1 git commit …` — which you use this once, after telling the user, and never again; everything after goes through a branch + PR per slice. If the user chose a remote in Phase 3, create it and push the baseline now, exactly as they specified (name, visibility) — `ALLOW_MAIN=1 git push -u origin main`, the second and last use of the hatch.
3. Propose the milestone path: an ordered list of thin vertical slices, each with its loop size (and its wall-clock estimate on a time-boxed project) (typically: `00` scaffold — `mise.toml`, tooling, the "Commands" section of `CLAUDE.md` filled with commands that were actually run, the test command written to `.claude/hooks/gate-tests.cmd` (one line; it switches the implementer's red-bar gate on), **the app driver `/verify-slice` will use** (the stack's e2e tool as a dev dependency, or a script folder) and **a README whose run instructions were replayed on a clean clone** → core data model → feature slices → a short final pass: hardening, clean-state replay, the documents). Put whatever can be cut last; what must ship — run instructions, the account of what was cut — is kept true by every slice, never left to the last one.
4. Delete the toolkit clone.
5. **STOP.** Hand over with a short report: what was installed, conflicts merged, decisions recorded, smoke-test evidence, and the suggested first command — `/start-feature 00 <name>`, in a fresh `claude` session (the project's settings start it on `opus` at `high` effort).

Once the app can actually be launched (usually after slice 00), suggest running Claude Code's `/run-skill-generator` once: it records how to build and start the project so that `/run`, `/verify` and step 4 of `/verify-slice` can drive the real app without rediscovering the recipe each time.

The implementer's red-bar gate is installed (`gate-tests.sh`) and switched on by `.claude/hooks/gate-tests.cmd`; it runs only when an implementer ends. Optional hardening, to offer once the project's commands are stable: a session-level `Stop` hook that runs typecheck + lint and exits 2 on failure, so no turn of the orchestrator ends on a broken tree. It is deliberately not installed by default — it costs a run per turn.

## Local-only projects

When the user chose no remote, adapt the workflow section of the project's `CLAUDE.md` in Phase 4:

- **PR step** — the "PR" becomes the slice branch plus its description, written from `.github/pull_request_template.md` to `docs/prs/<NN>-<name>.md` and committed on the branch; the user reviews and merges locally.
- **Merge gate** — it stays: nothing of the next slice starts until the user says the branch is merged. The agent then checks it (`git branch --merged main` lists the branch) and starts from that main.
- **Security pass** — the `security-reviewer` agent works on `git diff $(git merge-base HEAD main)` and needs no remote. Claude Code's built-in `/security-review` needs `origin/HEAD` and fails without one: never create a remote just to satisfy it.

## Updating an already-bootstrapped project

If `.claude/skills/plan-feature/` already exists in the target, this is an update, not a bootstrap (a project without `.claude/skills/start-feature/` predates the per-gate contexts: `install.sh` adds it, and the skills it reports as conflicts are the ones that gained `context: fork` and `model` fields): run `install.sh` (conflicts = files that drifted from the toolkit), show the user a diff per conflict, and let them choose per file. A project that was bootstrapped from an older layout may hold the workflow as `.claude/commands/*.md` and a `verify` skill: list them, and propose replacing them with the current skills (a project skill named `verify` collides with Claude Code's bundled `/verify`).

`install.sh` never touches `CLAUDE.md` or `SCOPE_PLAN.md`, and neither do you on your own. But the workflow contract lives in `CLAUDE.md`: compare its "How to work with me" section with the one in `templates/CLAUDE.template.md`, show the user what changed in the toolkit since (new steps, new gates), and apply only what they accept. Finish with the wiring test of Phase 5 and a `chore: update agentic workflow (toolkit @ <revision>)` commit on a branch.
