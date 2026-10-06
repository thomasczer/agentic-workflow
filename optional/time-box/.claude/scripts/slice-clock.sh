#!/usr/bin/env bash
# Wall clock of a time-boxed project. Reads two lines of SCOPE_PLAN.md:
#     - **T0**: 2026-08-18 15:27            (when the clock started; local time)
#     - **Limit**: 120 min (hard)           (or "(soft)")
# and prints elapsed, remaining, the stop time, and how long the current slice has been running
# (since the last commit on the default branch, i.e. the previous merge — or since T0).
# Everything counts: planning, waiting for an approval, reviews, the PR. No exclusions.
# Informational: always exits 0. Without a T0 it says so and stops.
# Usage: bash .claude/scripts/slice-clock.sh [path/to/SCOPE_PLAN.md]
set -uo pipefail

# Default: the SCOPE_PLAN.md at the top of the repository, wherever the command is run from.
top=$(git rev-parse --show-toplevel 2>/dev/null || true)
plan="${1:-${top:-.}/SCOPE_PLAN.md}"
[ -f "$plan" ] || { echo "slice-clock: $plan not found"; exit 0; }

t0=$(grep -m1 -E '^\s*[-*]?\s*\*\*T0\*\*' "$plan" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}' | head -1)
limit_line=$(grep -m1 -E '^\s*[-*]?\s*\*\*Limit\*\*' "$plan" || true)
limit=$(printf '%s' "$limit_line" | grep -oE '[0-9]+[[:space:]]*min' | grep -oE '[0-9]+' | head -1)
if [ -z "${limit:-}" ]; then # "2 h", "2h", "2 hours"
  hours=$(printf '%s' "$limit_line" | grep -oiE '[0-9]+[[:space:]]*h' | grep -oE '[0-9]+' | head -1)
  [ -n "${hours:-}" ] && limit=$(( hours * 60 ))
fi
[ -n "$limit_line" ] && [ -z "${limit:-}" ] && echo "slice-clock: cannot read the **Limit** line — write it as '<N> min (hard|soft)'"
kind=$(printf '%s' "$limit_line" | grep -oiE '\((hard|soft)\)' | tr -d '()' | tr 'A-Z' 'a-z' | head -1)

if [ -z "${t0:-}" ]; then
  echo "slice-clock: no **T0** line in $plan — this project is not time-boxed, or the clock was never started."
  exit 0
fi

epoch() { # epoch "<YYYY-MM-DD HH:MM>" → seconds (GNU date, BSD date, or python3)
  date -d "$1" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M' "$1" +%s 2>/dev/null ||
    python3 -c 'import sys,time; print(int(time.mktime(time.strptime(sys.argv[1], "%Y-%m-%d %H:%M"))))' "$1" 2>/dev/null
}
hm() { date -d "@$1" +%H:%M 2>/dev/null || date -r "$1" +%H:%M 2>/dev/null; }

now=$(date +%s)
start=$(epoch "${t0/T/ }")
[ -n "${start:-}" ] || { echo "slice-clock: cannot read the T0 date '$t0'"; exit 0; }
elapsed=$(( (now - start) / 60 ))

line="now $(date '+%F %H:%M') · T0 $(hm "$start") · elapsed ${elapsed} min"
if [ -n "${limit:-}" ]; then
  remaining=$(( limit - elapsed ))
  line="$line · limit ${limit} min (${kind:-soft}) · stop at $(hm $(( start + limit * 60 )))"
  if [ "$remaining" -ge 0 ]; then line="$line · remaining ${remaining} min"
  else line="$line · OVER by $(( -remaining )) min"; fi
fi
echo "$line"

# The current slice: since the previous merge landed on the default branch.
base=$(git symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
found=""
for b in "${base:-}" main master; do
  [ -n "$b" ] && git rev-parse -q --verify "$b" >/dev/null 2>&1 && { found="$b"; break; }
done
last=""
[ -n "$found" ] && last=$(git log -1 --format=%ct "$found" 2>/dev/null || true)
if [ -z "$found" ]; then
  echo "this slice: unknown — no default branch found (origin/HEAD unset, no main or master)"
elif [ -n "${last:-}" ] && [ "$last" -gt "$start" ]; then
  echo "this slice: $(( (now - last) / 60 )) min since the last commit on ${found} ($(hm "$last"))"
else
  echo "this slice: ${elapsed} min (no merge since T0)"
fi
# Projection, from the "Time budget" table of the plan (columns named Estimate and Measured):
# elapsed + estimates of the slices not measured yet × (measured so far ÷ estimated so far).
# The slice in progress is counted at its full estimate although part of it is already in
# "elapsed": the projection errs on the late side, on purpose. Buffer rows are left out.
awk -F'|' -v elapsed="$elapsed" -v limit="${limit:-0}" '
  function num(x) { gsub(/[^0-9.]/, "", x); return x }
  /\|/ && tolower($0) ~ /estimate/ && tolower($0) ~ /measured/ && !e {
    for (i = 1; i <= NF; i++) { h = tolower($i); if (h ~ /estimate/ && !e) e = i; if (h ~ /measured/ && h !~ /cumul/ && !m) m = i }
    next
  }
  e && /^[[:space:]]*\|[[:space:]]*:?-{3,}/ { next }   # the separator row under the header
  e && tolower($0) ~ /buffer/ { next }               # a buffer is not work still to come
  e && /\|/ {
    est = num($e); mea = num($m)
    if (est == "") next
    if (mea != "") { est_done += est; mea_done += mea } else est_left += est
    next
  }
  e && !/\|/ && seen_row { exit }
  e { seen_row = 1 }
  END {
    if (!e) exit
    ratio = (est_done > 0) ? mea_done / est_done : 1
    proj = elapsed + est_left * ratio
    printf "projection: %d min (elapsed %d + %d min of estimates still to come × %.2f measured/estimated)", proj, elapsed, est_left, ratio
    if (limit > 0) printf (proj > limit ? " — OVER the limit by %d min: propose a cut now" : " — %d min under the limit"), (proj > limit ? proj - limit : limit - proj)
    printf "\n"
  }
' "$plan"
exit 0
