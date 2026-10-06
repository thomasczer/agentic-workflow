#!/usr/bin/env bash
# SubagentStop hook of the `implementer` agent (declared in .claude/agents/implementer.md): the
# deterministic version of "never end on a red bar".
#   - The project's test command is the first non-comment line of `.claude/hooks/gate-tests.cmd`,
#     written in slice 00 once the project has tests. No file, or an empty one: the gate is OFF (exit 0).
#   - The command runs at the root of the repository the agent is working in — its worktree when it
#     has one (`cwd` of the hook input follows the agent; $CLAUDE_PROJECT_DIR does not).
#   - A non-zero exit blocks the agent from stopping: exit 2, and stderr (the tail of the output) is
#     fed back to it. Claude Code caps consecutive blocks, so a command that cannot pass does not loop.
# Needs jq or python3 to read its input; without them the gate is inert, like guard-git.sh.
set -uo pipefail

input=$(cat)

field() { # field <jq-path> <python-expr>
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c "import json,sys
try:
    j=json.load(sys.stdin); print($2 or '')
except Exception: pass" 2>/dev/null
  fi
}

cwd=$(field '.cwd' "j.get('cwd')")
cwd=${cwd:-$PWD}
[ -d "$cwd" ] || exit 0
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")

# The command file of the checkout the agent works in, else the project's (a worktree is a checkout
# of the same repository, so the two are normally identical).
cmdfile=""
for d in "$root" "${CLAUDE_PROJECT_DIR:-}"; do
  [ -n "$d" ] && [ -f "$d/.claude/hooks/gate-tests.cmd" ] && { cmdfile="$d/.claude/hooks/gate-tests.cmd"; break; }
done
[ -n "$cmdfile" ] || exit 0
cmd=$(grep -v -E '^[[:space:]]*(#|$)' "$cmdfile" | head -1)
[ -n "$cmd" ] || exit 0

# Hooks run in a non-interactive shell: make mise-managed tools reachable.
mise_shims="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
[ -d "$mise_shims" ] && PATH="$mise_shims:$PATH"

out=$(cd "$root" && bash -c "$cmd" 2>&1)
code=$?
[ "$code" -eq 0 ] && exit 0

{
  echo "Blocked by .claude/hooks/gate-tests.sh: \`$cmd\` exited $code in $root — the task is not done while the bar is red. Find out whether the test or the code is wrong, fix it, re-run, and only then end with your report (if the command itself cannot run here, say so in the report with its output). Last lines:"
  printf '%s\n' "$out" | tail -n 30
} >&2
exit 2
