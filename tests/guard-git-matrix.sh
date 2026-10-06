#!/usr/bin/env bash
# Command matrix for payload/.claude/hooks/guard-git.sh. Builds throwaway repositories, feeds the
# hook simulated PreToolUse payloads, and compares exit codes (0 = allowed, 2 = blocked).
# Usage: bash tests/guard-git-matrix.sh        (needs git and jq)
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
H="$here/payload/.claude/hooks/guard-git.sh"
G="$(mktemp -d)"; trap 'rm -rf "$G"' EXIT
for r in onmain onfeat "with space"; do
  git init -q -b main "$G/$r"
  git -C "$G/$r" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init
done
git -C "$G/onfeat" switch -q -c feat/01-x
pass=0; fail=0
t() { # t <expected> <cwd> <command>
  got=$(printf '%s' "$(jq -n --arg c "$3" --arg d "$2" '{cwd:$d,tool_input:{command:$c}}')" | bash "$H" >/dev/null 2>&1; echo $?)
  if [ "$got" = "$1" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL expected $1 got $got | cwd=$(basename "$2") | $3"; fi
}
M="$G/onmain"; F="$G/onfeat"
# --- unchanged behaviour
t 2 $M 'git commit -m x'
t 2 $M 'git push'
t 2 $M 'git -c user.name=x commit -m x'
t 0 $M 'ALLOW_MAIN=1 git commit -m x'
t 0 $F 'git commit -m x'
t 0 $F 'git push -u origin feat/01-x'
t 2 $F 'git push --force'
t 0 $F 'git push --force-with-lease'
t 0 $M 'git switch -c feat/02-y'
t 0 $M 'git checkout -b feat/02-y'
t 2 $F 'git switch -c feat/02-y'
t 2 $F 'git checkout -b feat/02-y'
t 0 $F 'ALLOW_STACK=1 git switch -c feat/02-y'
t 0 $M 'git status && ls'
t 0 $M 'echo "git commit is a word here"; ls'
# --- false positive 1: a -c that belongs to another program
t 0 $F 'gh pr view 6 --json state && git switch -q main && git pull -q --ff-only && rg -c "x" README.md'
t 0 $F 'rg -c foo . ; git switch main'
t 0 $F 'git -c core.pager=cat switch main'
t 2 $F 'rg -c foo . ; git switch -c feat/02-y'
t 2 $F 'git -c core.pager=cat switch --create feat/02-y'
t 0 $F 'git checkout main -- file.txt && grep -b x file.txt'
# --- false positive 2: the command targets another repository
t 0 $M "cd $F && git commit -m x"
t 0 $M "cd $F && git add -A && git commit -q -m x && git log --oneline -1"
t 0 $M "git -C $F commit -m x"
t 2 $F "cd $M && git commit -m x"
t 2 $F "git -C $M commit -m x"
t 2 $F "git -C $M push"
t 2 $M "cd $F && true; cd $M && git commit -m x"
t 0 $F "cd $M && ls; cd $F && git commit -m x"
t 2 $M "cd \"$G/with space\" && git commit -m x"
t 0 $M "cd $G && cd onfeat && git commit -m x"
t 0 $G "cd onfeat && git commit -m x"
t 2 $G "cd onmain && git commit -m x"
t 2 $M 'cd $SOMEWHERE && git commit -m x'
t 2 $M "cd /nonexistent/dir && git commit -m x"
t 2 $M "cd $F && git switch -c feat/03-z"
t 0 $F "cd $M && git switch -c feat/03-z"
# --- regressions found in review: the session's main must stay guarded when the parse is not trivial
t 2 $M "git -C $F status && git commit -m x"
t 2 $M "git -C $F log -1; git push"
t 2 $M "(cd $F && ls); git commit -m x"
t 2 $M "cd $F && git commit -m x; cd $M && git commit -m y"
t 2 $M "echo 'see cd $F' && git commit -m x"
t 2 $M "echo 'x; cd $F' && git commit -m x"
t 2 $M "git commit -m 'like git -C $F does'"
t 2 $M "cd $F; popd; git commit -m x"
t 2 $M "pushd $F; popd; git commit -m x"
t 2 $M "cd $F && cd - && git commit -m x"
# --- the targeted repository, harder forms
t 2 $F "cd -P $M && git commit -m x"
t 2 $F "cd -- $M && git commit -m x"
t 2 $F "pushd $M && git commit -m x"
t 2 $F "git --no-pager -C $M commit -m x"
t 2 $F "git -c a=b -C $M commit -m x"
t 2 $G "cd onfeat && git -C ../onmain commit -m x"
t 0 $G "cd onmain && git -C ../onfeat commit -m x"
t 2 $F "git -C \"$G/with space\" commit -m x"
t 0 $M "cd \"$F\" && git commit -m \"feat: x (y)\""
t 0 $M "cd $F && git add -A && git commit -q -m \"docs: a 'quoted' word; and (parens)\" && git log --oneline -1"
# --- newlines, environment prefixes, heredoc-looking text
t 0 $M "cd $F
git add -A
git commit -m x"
t 2 $F "cd $M
git commit -m x"
t 0 $M "cd $F && GIT_AUTHOR_NAME=t git commit -m x"
t 2 $M "FOO=1 git commit -m x"
t 2 $M "cd $F && git status; git -C $M commit -m x"
t 2 $M "cd $F || git commit -m x"
echo "passed $pass, failed $fail"; [ "$fail" -eq 0 ]
