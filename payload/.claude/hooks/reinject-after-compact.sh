#!/usr/bin/env bash
# SessionStart hook, matcher `compact`: after a compaction (/compact or automatic), re-injects the state
# of the slice that a summary must not lose — the branch, the plan, the commits and the files changed on
# the branch. This is the documented way to add context after a compaction: a SessionStart hook's plain
# stdout reaches the session; PreCompact and PostCompact cannot add any. What git cannot rebuild — the
# commands that were run, the user's answers — is left to the summary (CLAUDE.md asks for it).
# Read-only, git only; outside a git work tree it prints nothing.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$(git branch --show-current 2>/dev/null)
echo "State of the slice after compaction, read from git by .claude/hooks/reinject-after-compact.sh:"
echo "- branch: ${branch:-(detached HEAD)}"
# The plan of slice <NN> is docs/plans/<NN>-<name>.md, on branch feat/<NN>-<name>.
nn=$(printf '%s' "$branch" | sed -n 's#^feat/\([0-9][0-9]*\)-.*#\1#p')
if [ -n "$nn" ]; then
  plan=$(ls docs/plans/"$nn"-*.md 2>/dev/null | head -1)
  echo "- plan: ${plan:-none yet in docs/plans/ for slice $nn}"
fi

base=""
for b in main master; do git rev-parse --verify -q "$b" >/dev/null && { base=$b; break; }; done
if [ -n "$base" ] && [ "$branch" != "$base" ] && mb=$(git merge-base HEAD "$base" 2>/dev/null); then
  echo "- commits since $base (newest first, at most 15):"
  git log --oneline -15 "$mb"..HEAD | sed 's/^/    /'
  echo "- files changed since $base, committed or not (at most 40):"
  git diff --name-status "$mb" | head -40 | sed 's/^/    /'
fi
untracked=$(git ls-files --others --exclude-standard | head -20)
[ -z "$untracked" ] || { echo "- untracked files (at most 20):"; printf '%s\n' "$untracked" | sed 's/^/    /'; }
exit 0
