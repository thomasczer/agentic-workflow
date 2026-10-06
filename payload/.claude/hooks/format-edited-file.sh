#!/usr/bin/env bash
# PostToolUse hook: format + autofix the file the agent just edited.
# Best-effort and NON-BLOCKING — it never fails the tool call or nags the agent.
# Every formatter is optional: a missing tool is a silent no-op, so this file
# works unchanged across stacks. Trim the branches you don't need, or add yours.
set -uo pipefail

input=$(cat)

# Extract tool_input.file_path from the hook payload with whatever is available.
extract_path() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_input.file_path // empty'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception: pass'
  elif command -v node >/dev/null 2>&1; then
    node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{process.stdout.write(JSON.parse(d).tool_input?.file_path||"")}catch{}})'
  fi
}

file=$(printf '%s' "$input" | extract_path 2>/dev/null || true)

[ -z "${file:-}" ] && exit 0
[ ! -f "$file" ] && exit 0

# Hooks run in a non-interactive shell: make mise-managed tools reachable.
mise_shims="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
[ -d "$mise_shims" ] && PATH="$mise_shims:$PATH"

have() { command -v "$1" >/dev/null 2>&1; }
quiet() { "$@" >/dev/null 2>&1 || true; }

# The nearest ancestor of the edited file that holds <marker>: tools are resolved from the package
# the file belongs to, not from the repository root (monorepos, an app nested in `web/`…).
nearest() { # nearest <marker> → directory, or nothing
  # `pwd -P`: git prints the physical path of the top level, so the boundary check below must compare
  # physical paths too (macOS: /var → /private/var; a logical path never matches and the walk escapes).
  local d top; d=$(cd "$(dirname "$file")" 2>/dev/null && pwd -P) || return 0
  # Never look above the repository: a stray ~/node_modules must not format the project.
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -e "$d/$1" ] && { printf '%s' "$d"; return 0; }
    [ "$d" = "$top" ] && return 0
    d=$(dirname "$d")
  done
}
# Runs a JS tool: the binary from the nearest node_modules that has it (the package's own, or a
# workspace root's when dependencies are hoisted), the working directory being the file's package
# so that its config is the one found. Works with npm, pnpm, yarn and bun installs.
js_tool() { # js_tool <bin> <args…>
  local bin="$1" home; shift
  home=$(nearest "node_modules/.bin/$bin")
  [ -n "$home" ] && (cd "${pkg:-$home}" && quiet "$home/node_modules/.bin/$bin" "$@")
}

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.jsonc|*.css|*.scss|*.html|*.vue|*.svelte|*.md|*.yml|*.yaml)
    pkg=$(nearest package.json)
    if [ -n "$(nearest node_modules/.bin/biome)" ]; then
      # Biome formats and applies its safe fixes in one pass; files it does not handle are ignored.
      js_tool biome check --write --no-errors-on-unmatched "$file"
    else
      js_tool prettier --write "$file"
      case "$file" in
        *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte) js_tool eslint --fix "$file" ;;
      esac
    fi
    ;;
esac

case "$file" in
  *.py)
    if have ruff; then quiet ruff format "$file"; quiet ruff check --fix "$file"
    elif have black; then quiet black -q "$file"; fi
    ;;
  *.go)
    have gofmt && quiet gofmt -w "$file"
    ;;
  *.rs)
    crate=$(nearest Cargo.toml)
    edition=$(grep -m1 -E '^edition' "${crate:-.}/Cargo.toml" 2>/dev/null | grep -oE '[0-9]{4}')
    have rustfmt && quiet rustfmt --edition "${edition:-2021}" "$file"
    ;;
  *.rb)
    have rubocop && quiet rubocop -a "$file"
    ;;
  *.php)
    php=$(nearest composer.json)
    [ -n "$php" ] && [ -x "$php/vendor/bin/pint" ] && (cd "$php" && quiet vendor/bin/pint "$file")
    ;;
  *.ex|*.exs)
    have mix && quiet mix format "$file"
    ;;
  *.kt|*.kts)
    have ktlint && quiet ktlint -F "$file"
    ;;
  *.sh)
    have shfmt && quiet shfmt -w "$file"
    ;;
esac

exit 0
