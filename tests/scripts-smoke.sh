#!/usr/bin/env bash
# Smoke test of slice-clock.sh (sub-directory, "2 h" limit, projection from the budget table, unreadable
# limit, no default branch), of the format hook repository boundary, and of the implementer's red-bar
# gate (gate-tests.sh: off without a command file, blocks on red, passes on green, runs at the repo root). Read the output; needs git, jq.
# Usage: bash tests/scripts-smoke.sh
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
K="$here/optional/time-box/.claude/scripts/slice-clock.sh"
H="$here/payload/.claude/hooks/format-edited-file.sh"
G="$here/payload/.claude/hooks/gate-tests.sh"
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
