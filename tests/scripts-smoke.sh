#!/usr/bin/env bash
# Smoke test of slice-clock.sh (sub-directory, "2 h" limit, projection from the budget table, unreadable
# limit, no default branch), of the format hook (repository boundary, mix from the nearest mix.exs), of the implementer's red-bar
# gate (gate-tests.sh: off without a command file, blocks on red, passes on green, runs at the repo root)
# and of the orchestrator check (orchestrator-check.sh: records the model — under claude -p from the --model flag or ANTHROPIC_MODEL —, blocks /start-feature off-model). Read the output; needs git, jq.
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
echo "--- format hook runs mix format from the nearest mix.exs (a stub mix records its directory):"
mkdir -p "$T/bin" "$T/repo/backend/lib" && printf '#!/bin/sh\necho "$(pwd -P) $*" >> %s/mix-calls\n' "$T" > "$T/bin/mix" && chmod +x "$T/bin/mix"
touch "$T/repo/backend/mix.exs" && echo 'x' > "$T/repo/backend/lib/a.ex"
# MISE_DATA_DIR off: the hook puts mise shims first in PATH, and a real mix there would shadow the stub.
jq -n --arg f "$T/repo/backend/lib/a.ex" '{tool_input:{file_path:$f}}' | (cd "$T/repo" && MISE_DATA_DIR="$T/no-mise" PATH="$T/bin:$PATH" bash "$H"); rc=$?
Tp=$(cd "$T" && pwd -P); got=$(cut -d' ' -f1 "$T/mix-calls" 2>/dev/null)
echo "hook exit $rc; mix ran in: ${got#"$Tp"/} (expect repo/backend) — $([ "$got" = "$Tp/repo/backend" ] && echo ok || echo WRONG)"
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
echo "--- orchestrator check under claude -p (SessionStart has no model; the hook reads the launch command line):"
unset ANTHROPIC_MODEL
# A stand-in for the claude process: its command line carries the flags, CLAUDE_PID points at it.
fake() { bash -c 'sleep 30; :' claude "$@" >/dev/null 2>&1 & echo $!; }
stop() { pkill -P "$1" 2>/dev/null; kill "$1" 2>/dev/null; }
hp() { # hp <session> <source> <pid> → SessionStart without a model, then /start-feature
  jq -n --arg s "$1" --arg src "$2" '{hook_event_name:"SessionStart",session_id:$s,source:$src}' | CLAUDE_PID="$3" bash "$O" >/dev/null 2>&1
  jq -n --arg s "$1" '{hook_event_name:"UserPromptSubmit",session_id:$s,prompt:"/start-feature 00 wiring"}' | bash "$O" > "$T/oc.out" 2>&1
  echo "exit $? — $(head -c 70 "$T/oc.out")"
}
# Markers land in the HOME cache here: -p inputs carry no scratchpad_dir.
export HOME="$T/home" XDG_CACHE_HOME=
p=$(fake --model sonnet -p "/start-feature 00 wiring")
printf -- '--model sonnet -p (expect exit 2, Blocked…): '; hp p-1 startup "$p"
printf -- 'same command line after /clear (source clear: not trusted, expect exit 0, a note): '; hp p-2 clear "$p"
stop "$p"
p=$(fake --model=claude-opus-5-5 -p "/start-feature 00 wiring")
printf -- '--model=claude-opus-5-5 -p (expect exit 0): '; hp p-3 startup "$p"
stop "$p"
p=$(fake --model best -p "/start-feature 00 wiring")
printf -- '--model best -p, an alias without a family (expect exit 0, a note): '; hp p-4 startup "$p"
stop "$p"
p=$(fake -p "/start-feature 00 wiring")
printf -- 'no flag, ANTHROPIC_MODEL=claude-sonnet-5-5 (expect exit 2): '; ANTHROPIC_MODEL=claude-sonnet-5-5 hp p-5 startup "$p"
printf -- 'no flag, no ANTHROPIC_MODEL: the settings model is not seen (expect exit 0, a note): '; hp p-6 startup "$p"
stop "$p"
printf -- 'no CLAUDE_PID in the hook environment (expect exit 0, a note): '; hp p-7 startup ""
