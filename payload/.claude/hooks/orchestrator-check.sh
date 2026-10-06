#!/usr/bin/env bash
# The orchestrator (/start-feature) runs on the model of the model table — `opus` by default, set by
# .claude/settings.json. A `--model` flag or ANTHROPIC_MODEL overrides that silently; this hook turns the
# mismatch into a block instead of a surprise:
#   - SessionStart: records the session's model in a marker keyed by session. An interactive session's
#     input carries it (`model`). A headless one (`claude -p`) does not (Claude Code 2.1.291): at startup
#     the hook then reads the `--model` flag from the command line of the claude process ($CLAUDE_PID),
#     else ANTHROPIC_MODEL, in that precedence (/model, which ranks above both, is interactive only).
#   - UserPromptSubmit: when the submitted prompt is /start-feature, compares the recorded model with the
#     expected family and BLOCKS the prompt (exit 2, message on stderr) when it does not match. Any other
#     prompt passes. So does a session whose model was not recorded, with a note the session reads as
#     context: after /clear (a new session id, no model in the input), and under `claude -p` when the
#     model comes from a settings file or the flag names no family (`--model best`).
# Expected family: $ORCHESTRATOR_MODEL (default `opus`; e.g. `ORCHESTRATOR_MODEL=fable claude --model fable`).
# The effort is checked by the skill itself (`${CLAUDE_EFFORT}` in start-feature/SKILL.md): hook inputs
# do not carry it at prompt time. Needs jq or python3; without them the check is inert, like guard-git.sh.
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

event=$(field '.hook_event_name' "j.get('hook_event_name')")
session=$(field '.session_id' "j.get('session_id')")
[ -n "$session" ] || exit 0
# The marker lives in the session's scratchpad when the input names one (private to the session), else
# in a 0700 directory under the user's cache — never in a shared /tmp, where a planted symlink would
# redirect the write or feed a forged model. A marker that is a link is never followed.
dir=$(field '.scratchpad_dir' "j.get('scratchpad_dir')")
{ [ -n "$dir" ] && [ -d "$dir" ] && [ ! -L "$dir" ]; } || dir="${XDG_CACHE_HOME:-$HOME/.cache}/agentic-workflow/sessions"
marker="$dir/orchestrator-model-$(printf '%s' "$session" | tr -c 'A-Za-z0-9._-' '_')"
[ -L "$marker" ] && exit 0

# The model a session was launched with, read from its command line, else its environment; only names
# that carry a model family count (an alias like `best` or `default` resolves elsewhere: unknown here).
launch_model() {
  local m=""
  [ -n "${CLAUDE_PID:-}" ] && m=$(ps -o args= -p "$CLAUDE_PID" 2>/dev/null | tr -s '[:space:]' '\n' |
    awk 'f { print; exit } /^--model=/ { sub(/^--model=/, ""); print; exit } $0 == "--model" { f = 1 }')
  [ -n "$m" ] || m="${ANTHROPIC_MODEL:-}"
  printf '%s' "$m" | grep -Eiq 'opus|sonnet|haiku|fable' && printf '%s' "$m"
}

case "$event" in
  SessionStart)
    model=$(field '.model' "j.get('model')")
    # Headless startup: no model in the input. Not after /clear or a resume, where /model may have
    # changed the model since launch: there, keep what was recorded.
    [ -n "$model" ] || [ "$(field '.source' "j.get('source')")" != startup ] || model=$(launch_model)
    [ -n "$model" ] || exit 0
    mkdir -p -m 700 "$dir" 2>/dev/null && printf '%s\n' "$model" > "$marker"
    exit 0
    ;;
  UserPromptSubmit)
    prompt=$(field '.prompt' "j.get('prompt')")
    # The raw command, or its expansion (the skill body).
    printf '%s' "$prompt" | grep -Eq '^[[:space:]]*/start-feature([[:space:]]|$)|You are the \*\*orchestrator\*\*' || exit 0
    expected="${ORCHESTRATOR_MODEL:-opus}"
    model=$(cat "$marker" 2>/dev/null || true)
    if [ -z "$model" ]; then
      echo "orchestrator-check: the model of this session was not recorded (no SessionStart with a model) — make sure it is \`$expected\`, the model of the orchestrator (see the model table of /start-feature)."
      exit 0
    fi
    printf '%s' "$model" | grep -iq "$expected" && exit 0
    echo "Blocked by .claude/hooks/orchestrator-check.sh: this session runs on \`$model\`, and /start-feature is the orchestrator, which runs on \`$expected\` (the model table of the skill; .claude/settings.json sets it as the project's default — a --model flag or ANTHROPIC_MODEL overrode it). Start a fresh session with no model flag, or \`claude --model $expected\`. To orchestrate on another model on purpose: \`ORCHESTRATOR_MODEL=<family> claude --model <model>\`." >&2
    exit 2
    ;;
esac
exit 0
