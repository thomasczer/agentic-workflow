#!/usr/bin/env bash
# PreToolUse hook (Bash): turns the git rules of CLAUDE.md into a deterministic gate.
#   - no `git commit` on main/master          (work happens on a branch per slice)
#   - no `git push` while on main/master      (the user merges PRs themselves)
#   - no `git push --force` anywhere          (--force-with-lease is allowed)
#   - no new branch created from a slice branch (`git switch -c`, `git checkout -b`):
#     a slice starts from the default branch, after the previous one is merged
# Exit 2 blocks the tool call and feeds stderr back to the agent.
# Escape hatch, for the user-approved bootstrap baseline only: prefix the command
# with ALLOW_MAIN=1 (e.g. `ALLOW_MAIN=1 git commit -m "chore: bootstrap ..."`).
# Stacking a branch on another one on purpose, with the user's agreement: ALLOW_STACK=1.
# Not covered: `git branch <name>` followed by a plain switch, and `git worktree add -b`.
# The branch that counts is the one of the repository the command targets (`cd <dir> && git …`,
# `git -C <dir> …`) when the command is plain enough to be read with certainty; otherwise the
# session's repository is judged too and the strictest answer wins. See the block further down.
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

cmd=$(field '.tool_input.command' "j.get('tool_input',{}).get('command')")
cwd=$(field '.cwd' "j.get('cwd')")
[ -z "${cmd:-}" ] && exit 0

# `git`, optional global flags (-C dir, -c k=v, --no-pager…), then the subcommand.
val="(\"[^\"]*\"|'[^']*'|[^[:space:]]+)"
GIT="(^|[;&|(]|[[:space:]])git([[:space:]]+(-[cC][[:space:]]+$val|--?[a-zA-Z-]+(=[^[:space:]]+)?))*[[:space:]]+"
git_sub() { printf '%s' "$cmd" | grep -Eq "${GIT}$1([[:space:]]|\$)"; }

# The arguments of `git … <sub>`, up to the next command separator: a flag only counts when it
# belongs to that invocation (`rg -c … && git switch main` creates no branch).
sub_args() { printf '%s' "$cmd" | grep -oE "${GIT}$1([[:space:]][^;&|]*)?" | sed -E "s/.*[[:space:]]$1([[:space:]]|\$)/ /"; }

new_branch() { { git_sub switch && sub_args switch | grep -Eq '[[:space:]](-c|-C|--create|--force-create)([[:space:]]|$)'; } ||
  { git_sub checkout && sub_args checkout | grep -Eq '[[:space:]](-b|-B)([[:space:]]|$)'; }; }

git_sub commit || git_sub push || new_branch || exit 0

# ---- Which repository does the command act on? -------------------------------------------------
# Read from the command: the `cd` / `pushd` steps that precede the first guarded git invocation,
# in order, then that invocation's own `-C <dir>`. The reading is only TRUSTED when the command is
# plain: one guarded invocation, no subshell, no pushd/popd, no `cd -`, nothing quoted besides the
# directories themselves. Otherwise the guard judges the session's repository AND whatever it
# could resolve, and the strictest answer wins — an unusual command never loosens the gate.
GUARDED="(commit|push|switch|checkout)"
unquote() { sed -E "s/^[\"']//; s/[\"']\$//"; }
resolve() { # resolve <base> <dir> → absolute path, "" when it is not a directory
  local d="$2"
  case "$d" in "~"|"~/"*) d="$HOME${d#\~}" ;; esac
  case "$d" in /*) ;; *) d="$1/$d" ;; esac
  [ -d "$d" ] && printf '%s' "$d"
}

session="${cwd:-.}"
before_git=$(printf '%s' "$cmd" | sed -E "s/${GIT}${GUARDED}([[:space:]]|\$).*//")
invocation=$(printf '%s' "$cmd" | grep -oE "${GIT}${GUARDED}([[:space:]]|\$)" | head -1)
count=$(printf '%s' "$cmd" | grep -oE "${GIT}${GUARDED}([[:space:]]|\$)" | wc -l)

# A directory step: at the start or right after a separator, optional flags, one directory.
STEP="(^|[;&|])[[:space:]]*(cd|pushd)([[:space:]]+-[-a-zA-Z]*)*[[:space:]]+$val"
trusted=1
[ "$count" -eq 1 ] || trusted=0
leftover=$(printf '%s' "$before_git" | sed -E "s/$STEP/\1/g")
printf '%s' "$leftover" | grep -Eq "[\"'()\`]|(^|[^a-zA-Z_-])(cd|pushd|popd)([^a-zA-Z_-]|\$)" && trusted=0
printf '%s' "$before_git" | grep -Eq "(^|[;&|])[[:space:]]*pushd[[:space:]]" && trusted=0
# `cd <dir> || …`: what follows runs where the `cd` failed, i.e. in the session's directory.
case "$before_git" in *"||"*) trusted=0 ;; esac

target="$session"
while IFS= read -r step; do
  [ -z "$step" ] && continue
  case "$step" in -*) target=""; break ;; esac
  target=$(resolve "$target" "$step")
  [ -z "$target" ] && break
done < <(printf '%s' "$before_git" | grep -oE "$STEP" | sed -E "s/^[;&|]?[[:space:]]*(cd|pushd)([[:space:]]+-[-a-zA-Z]*)*[[:space:]]+//" | unquote)
[ -n "$target" ] || trusted=0

dash_c=$(printf '%s' "$invocation" | grep -oE "[[:space:]]-C[[:space:]]+$val" | tail -1 | sed -E "s/^[[:space:]]-C[[:space:]]+//" | unquote)
if [ -n "$dash_c" ]; then
  target=$(resolve "${target:-$session}" "$dash_c")
  [ -n "$target" ] || trusted=0
fi

branch_of() { git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null || true; }
if [ "$trusted" -eq 1 ]; then
  branches=$(branch_of "$target")
else
  branches=$(branch_of "$session"; echo; [ -n "$target" ] && [ "$target" != "$session" ] && branch_of "$target")
fi
on_default() { printf '%s\n' "$branches" | grep -Eq '^(main|master)$'; }
off_default() { printf '%s\n' "$branches" | grep -Ev '^(main|master)?$' | head -1; }

if new_branch; then
  stacked=$(off_default)
  [ -z "$stacked" ] && exit 0
  printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])ALLOW_STACK=1[[:space:]]' && exit 0
  echo "Blocked by .claude/hooks/guard-git.sh: you are on '$stacked', not on the default branch. A new slice starts from an up-to-date main once the previous PR is merged (merge gate) — tell the user this slice is waiting for their merge instead of stacking a branch on it." >&2
  exit 2
fi

if git_sub push && printf '%s' "$cmd" | grep -Eq '[[:space:]](--force|-f)([[:space:]]|$)'; then
  echo "Blocked by .claude/hooks/guard-git.sh: plain force-push is not allowed. Use --force-with-lease on your slice branch, or ask the user." >&2
  exit 2
fi

printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])ALLOW_MAIN=1[[:space:]]' && exit 0

if on_default; then
  echo "Blocked by .claude/hooks/guard-git.sh: this command would commit or push on the default branch. Create the slice branch first (git switch -c feat/<NN>-<name>) and commit there; the user merges PRs themselves. (If the command targets another repository, keep it plain — 'cd <dir> && git …' or 'git -C <dir> …' — so the guard can tell which one.)" >&2
  exit 2
fi

exit 0
