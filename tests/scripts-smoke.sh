#!/usr/bin/env bash
# Smoke test of slice-clock.sh (sub-directory, "2 h" limit, projection from the budget table, unreadable
# limit, no default branch), of the format hook repository boundary, of the implementer's red-bar
# gate (gate-tests.sh: off without a command file, blocks on red, passes on green, runs at the repo root)
# and of the orchestrator check (orchestrator-check.sh: records the model, blocks /start-feature off-model). Read the output; needs git, jq.
# Usage: bash tests/scripts-smoke.sh
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
K="$here/optional/time-box/.claude/scripts/slice-clock.sh"
H="$here/payload/.claude/hooks/format-edited-file.sh"
G="$here/payload/.claude/hooks/gate-tests.sh"
O="$here/payload/.claude/hooks/orchestrator-check.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# T0 = 100 minutes ago: GNU date (-d), else BSD/macOS date (-v).
t0=$(date -d '-100 min' '+%F %H:%M' 2>/dev/null || date -v-100M '+%F %H:%M')
mkdir -p "$T/repo/web" && cd "$T/repo" && git init -q -b main . &&
  git -c user.email=a@b.invalid -c user.name=t commit -q --allow-empty -m init
cat > SCOPE_PLAN.md <<EOF
## Time budget

- **T0**: $t0
- **Limit**: 2 h (hard)

| #   | Slice    | Loop  | Estimate (min) | Measured (min) | Cumulative measured / limit |
| --- | -------- | ----- | -------------- | -------------- | --------------------------- |
| 00  | Scaffold | light | 15             | 14             | 14 / 120                    |
| 01  | Auth     | full  | 25             | 32             | 46 / 120                    |
| 02  | Orders   | full  | 40             |                |                             |
| 03  | Reports  | light | 25             |                |                             |
|     | Buffer   |       | 10             |                |                             |

**Checkpoint rule.** text
EOF
echo "--- from a sub-directory, '2 h' limit, projection from the table:"
(cd web && bash "$K")
echo "--- unreadable limit:"
# -i.bak: in-place editing that both GNU and BSD sed accept (bare -i is GNU only).
sed -i.bak 's/2 h (hard)/soon (hard)/' SCOPE_PLAN.md && rm SCOPE_PLAN.md.bak && bash "$K" | head -2
echo "--- no default branch:"
git branch -q -m main trunk && bash "$K" | tail -2
echo "--- format hook must not use a node_modules above the repository:"
mkdir -p "$T/node_modules/.bin" && printf '#!/bin/sh\necho CALLED >> %s/calls\n' "$T" > "$T/node_modules/.bin/prettier" && chmod +x "$T/node_modules/.bin/prettier"
echo 'x' > "$T/repo/web/a.ts"
jq -n --arg f "$T/repo/web/a.ts" '{tool_input:{file_path:$f}}' | bash "$H"; echo "hook exit $?; stray prettier called: $([ -f "$T/calls" ] && echo YES || echo no)"
echo "--- gate-tests hook, from a sub-directory of the checkout:"
gate() { jq -n --arg c "$T/repo/web" '{cwd:$c}' | CLAUDE_PROJECT_DIR="$T/repo" bash "$G" > "$T/gate.out" 2>&1; echo "exit $? — $(head -c 90 "$T/gate.out")"; }
mkdir -p "$T/repo/.claude/hooks"
printf 'no command file: '; gate
printf '# the test command\ntest -f SCOPE_PLAN.md && echo at-root && false\n' > "$T/repo/.claude/hooks/gate-tests.cmd"
printf 'red (expect exit 2, Blocked…): '; gate
printf 'test -f SCOPE_PLAN.md\n' > "$T/repo/.claude/hooks/gate-tests.cmd"
printf 'green at the repo root (expect exit 0): '; gate
echo "--- orchestrator check (marker in the session scratchpad):"
mkdir -p "$T/scratch"
oc() { jq -n --arg e "$1" --arg m "$2" --arg p "$3" --arg s "$T/scratch" '{hook_event_name:$e,session_id:"smoke-1",model:$m,prompt:$p,scratchpad_dir:$s}' | bash "$O" > "$T/oc.out" 2>&1; echo "exit $? — $(head -c 70 "$T/oc.out")"; }
printf 'prompt before any SessionStart (expect exit 0, a note): '; oc UserPromptSubmit "" "/start-feature 01 x"
printf 'SessionStart on sonnet (expect exit 0): '; oc SessionStart claude-sonnet-5-5 ""
printf 'ordinary prompt on sonnet (expect exit 0): '; oc UserPromptSubmit "" "fix the typo in README"
printf '/start-feature on sonnet (expect exit 2, Blocked…): '; oc UserPromptSubmit "" "/start-feature 01 x"
printf 'expanded skill on sonnet (expect exit 2): '; oc UserPromptSubmit "" "Slice to run: 01 x. You are the **orchestrator**: you dispatch"
printf 'SessionStart without a model keeps the record (expect exit 2 after): '; oc SessionStart "" "" >/dev/null; oc UserPromptSubmit "" "/start-feature 01 x"
printf 'SessionStart on opus, then /start-feature (expect exit 0): '; oc SessionStart claude-opus-5-5 "" >/dev/null; oc UserPromptSubmit "" "/start-feature 01 x"
printf 'ORCHESTRATOR_MODEL=fable on fable (expect exit 0): '; oc SessionStart claude-fable-5-1 "" >/dev/null; ORCHESTRATOR_MODEL=fable oc UserPromptSubmit "" "/start-feature 01 x"
echo "victim" > "$T/victim"; rm -f "$T/scratch/orchestrator-model-smoke-1"; ln -s "$T/victim" "$T/scratch/orchestrator-model-smoke-1"
printf 'planted symlink at the marker: SessionStart must not write through it: '; oc SessionStart claude-sonnet-5-5 ""; echo "   victim still says: $(cat "$T/victim")"
printf 'planted symlink at the marker: /start-feature must not read through it (expect exit 0): '; oc UserPromptSubmit "" "/start-feature 01 x"
printf 'no scratchpad in the input: falls back to a 0700 dir under HOME/.cache (expect exit 2): '; HOME="$T/home" XDG_CACHE_HOME= bash -c 'jq -n "{hook_event_name:\"SessionStart\",session_id:\"smoke-2\",model:\"claude-sonnet-5-5\"}" | bash "$0" >/dev/null; jq -n "{hook_event_name:\"UserPromptSubmit\",session_id:\"smoke-2\",prompt:\"/start-feature 01 x\"}" | bash "$0" >/dev/null 2>&1; echo "exit $? — mode $(stat -f %Lp "$HOME/.cache/agentic-workflow/sessions" 2>/dev/null || stat -c %a "$HOME/.cache/agentic-workflow/sessions")"' "$O"
