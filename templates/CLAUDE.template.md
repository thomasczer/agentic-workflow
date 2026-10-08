<!--
  CLAUDE.md template, filled in during bootstrap (see BOOTSTRAP.md in the toolkit repo).
  The universal engineering principles are already written. Every HTML comment and every
  <placeholder> is project-specific: replace it with real content or delete it.
  None may survive bootstrap, including this one.
-->

# <Project name>

<!-- One or two sentences: what this project is and the current goal / scope. -->

Scope, milestone path and time budget live in `SCOPE_PLAN.md` — read it before starting any feature work. Decisions are in `docs/decisions.md`: look one up by its number, never read the file whole.

## Stack

<!-- Language, framework, database, key libraries. One line each, with exact major versions, and the "why" where it's a real choice you'd defend. -->

Runtimes and dev tools are pinned in `mise.toml` and managed by `mise` only — never install a runtime or version manager another way. If a command is not found, run it through `mise exec --`.

<!-- VERSION TRAPS: for every dependency whose installed major version may be newer than the agent's training data, add a bold warning here saying where the authoritative docs are (bundled docs in the package, official site) and that they must be read before writing code against it. Assumptions about library APIs are verified by reading or running, never guessed. -->

## Commands

<!-- The exact commands for THIS project. Only commands that were actually run may appear; before the project is scaffolded, write "n/a until slice 00". Keep the labels stable — the skills refer to them by label. Write "n/a" for a label the stack doesn't have. -->

<!-- Keep only the everyday commands here (this file is loaded by every context). Everything else — per-flow e2e inventories, pilot scripts, ops, deploy — goes to `docs/commands.md`, one line per topic, under the same rule: only commands that were actually run. -->

- run / dev: `...`
- build: `...`
- typecheck: `...`
- lint: `...`
- test: `...`
- e2e / app driver: `...` <!-- the tool that drives the real app for /verify-slice (Playwright, an HTTP script folder, a CLI transcript…); set up in slice 00, extended by every slice -->
- <migrations / seed / codegen / etc.>: `...`

## Definition of Done — never claim "done" without evidence

Before committing any change:

1. Typecheck passes.
2. Lint passes.
3. The tests covering the change pass.
4. The **actual behavior was exercised** (drove the UI / hit the endpoint / observed the output). "It compiles" is not verification.
5. The current-state documents are still true (see "Where things are written"): what is built, how to run it, what was cut and why. The repository must be shippable after every merge, not only after the last one.

Run `/verify-slice` to do this properly.

## Conventions

<!-- Fill from this codebase's real patterns: folder structure, where data access / business logic lives, how mutations happen, validation approach, error handling. -->

- Keep files focused — one clear responsibility each; a file doing two jobs is a signal to split it.
- Validate every external input at the boundary. Never trust a client-supplied id or amount.
- Entry points (route handlers, controllers, CLI commands) stay thin and call into logic modules.
- Anything someone should hear — a gap or a contradiction in the spec or the designs, a limit of an API we depend on, a known limitation, something only I can do — is written down the moment it is noticed, where "Where things are written" says. Not in the plan: plans are not read again.
- <add project conventions>

## Where things are written

Three kinds, never mixed in one file: current state is rewritten, history is appended, open work is queued.

- **Current state — rewritten, short.** `README.md` (what it is, how to run it, current limitations, links; about 150 lines), `SCOPE_PLAN.md` (the sentence, priorities, Won't, milestone path), `docs/<topic>.md` (an API, the architecture, a feature's walkthrough). A slice edits what it changed and deletes what is no longer true; git keeps the history.
- **History — appended, never read whole.** `docs/decisions.md` (one numbered entry per decision of mine: what, why, who, when; a later one says "supersedes Dn"), `docs/adr/` for the structural ones, `docs/plans/`, commits and PR bodies.
- **Open work — queued.** GitHub issues, opened with `gh issue create --label <label>`: `spec-gap` (a gap or contradiction in the spec or designs), `follow-up` (work cut from a slice, a limit to lift), `ops` (an action outside the code, often mine). The slice that does one closes it (`Closes #N` in the PR).
- **What an agent needs while touching an area** — a library trap, a test-environment quirk: `.claude/rules/<area>.md` with a `paths:` frontmatter, so it loads only for matching files.

## Security

<!-- General hygiene always applies; add the rules specific to this project's threat model. Delete the bullets that cannot apply (e.g. webhooks in a CLI tool). -->

- Authorize every privileged action **server-side**; never rely on the client to enforce access.
- Never trust client-supplied identifiers, prices, or amounts — re-derive them server-side.
- Verify signatures on inbound webhooks / callbacks; make their handlers idempotent.
- Secrets live in env / a secret store, never in code or git. Document required vars in `.env.example`.
- Untrusted input is validated on the way in and treated as plain text on the way out.
- <add project-specific rules: authz model, tenant isolation, sensitive fields>

## Testing

- Test the risky / business-critical logic and the security boundaries. Don't chase coverage on trivial glue.
- Prefer integration tests around real seams over mocking everything.
- Priority order here: <the 3–4 riskiest behaviors of THIS project, most critical first>

## Git & PR discipline

- Small atomic commits, Conventional Commits (`feat:`, `fix:`, `test:`, `chore:`, `docs:`).
- Use TDD where it fits: a failing `test:` (red) then the `feat:` that greens it.
- PRs explain: context → approach → trade-offs → how verified (`.github/pull_request_template.md`).

## How to work with me (the agent)

Every slice lives on its own branch `feat/<NN>-<name>`, created from an up-to-date main — plan included. **Never commit directly to main** after the bootstrap baseline, and never start a branch from another slice's branch (both enforced by `.claude/hooks/guard-git.sh`).

**One session per slice, started by `/start-feature <NN> <name>` in a fresh session (the project's settings start it on `opus` at `high` effort), closed when the PR is open.** That session orchestrates: each gate runs in its own fresh context on its own model and effort (the loop, the gates and the model table live in `.claude/skills/start-feature/SKILL.md`, the single source), and only the orchestrator talks to me. The loop has **four stops and only four**; between two stops the orchestrator chains the gates itself, without asking whether to go on, and never idles while I read:

1. **Stop 1** — my approval of the plan (`docs/plans/`, declaring `Loop: full | light`, which I can overrule). No test is made green before it.
2. **Stop 2**, only if the slice has one — a design checkpoint: a load-bearing artifact (schema, migration, API contract, auth model; client-side: state that outlives a screen or a session, a route contract, the module every request goes through) is presented and validated before anything is built on it. A plan approval is not an artifact approval.
3. **Stop 3**, only when it happens — a review finding that changes scope, a recorded decision, visible behaviour or a load-bearing artifact, or that could not be confirmed. Never dropped silently.
4. **Stop 4** — the merge, which is mine. Opening the PR ends the slice: nothing of the next one starts until I say it is merged (`gh pr view <N> --json state` → `MERGED`); an approval in chat is not a merge, and at most one PR is open at any time.

A one-sentence diff (typo, rename, log line, dependency bump) skips the plan, TDD and the reviewers: branch, change, `/verify-slice`, PR. When the spec or a decision is ambiguous: options with trade-offs and a recommendation; the decision is mine and gets recorded in `docs/decisions.md`. This workflow takes precedence over any equivalent skill injected by an installed plugin (planning, brainstorming, TDD, verification, review); plugin agents may still serve as extra reviewers.

This file is loaded by every context, so it stays short: everyday commands here, the rest in `docs/commands.md`. When compacting, always preserve the commands that were run with their outcome, and my answers and decisions; the branch, the plan path and the changed files are re-injected from git after every compaction (`.claude/hooks/reinject-after-compact.sh`).

## Out of scope

<!-- Mirror the "Won't" list of SCOPE_PLAN.md. -->

Do not build these; if a task seems to need one, stop and flag it.
