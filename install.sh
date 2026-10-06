#!/usr/bin/env bash
# Copies the workflow payload into a target project. Deterministic and NO-CLOBBER:
# an existing file is never overwritten — it is reported as a conflict for the
# agent (or human) to merge by hand.
#
#   bash install.sh <target-dir> [--with <optional-module>]...
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target=""
modules=()

while [ $# -gt 0 ]; do
  case "$1" in
    --with) modules+=("${2:?--with needs a module name}"); shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) target=$1; shift ;;
  esac
done

[ -n "$target" ] || { echo "usage: install.sh <target-dir> [--with <module>]..." >&2; exit 2; }
[ -d "$target" ] || { echo "target is not a directory: $target" >&2; exit 2; }
target=$(cd "$target" && pwd)
[ "$target" != "$here" ] || { echo "refusing to install the toolkit into itself" >&2; exit 2; }

installed=() conflicts=()

# copy_tree <src> [<find-filter>...] — extra args are passed to find.
copy_tree() {
  local src=$1 f rel dest; shift
  while IFS= read -r -d '' f; do
    rel=${f#"$src"/}
    dest="$target/$rel"
    if [ -e "$dest" ]; then
      cmp -s "$f" "$dest" || conflicts+=("$rel  (toolkit version: $f)")
    else
      mkdir -p "$(dirname "$dest")"
      cp "$f" "$dest"
      installed+=("$rel")
    fi
  done < <(find "$src" -type f "$@" -print0 | sort -z)
}

copy_tree "$here/payload"

# `${arr[@]+"${arr[@]}"}`: an empty array is "unbound" for bash 3.2 (macOS) under `set -u`.
for m in ${modules[@]+"${modules[@]}"}; do
  [ -d "$here/optional/$m" ] || { echo "unknown optional module: $m" >&2; exit 2; }
  copy_tree "$here/optional/$m" ! -path "$here/optional/$m/README.md"
done

chmod +x "$target"/.claude/hooks/*.sh 2>/dev/null || true

rev=$(git -C "$here" rev-parse --short HEAD 2>/dev/null || echo unknown)
echo "toolkit revision: $rev"
echo "installed (${#installed[@]}):"; [ ${#installed[@]} -eq 0 ] || printf '  %s\n' ${installed[@]+"${installed[@]}"}
if [ ${#conflicts[@]} -gt 0 ]; then
  echo "CONFLICTS — already exist and differ, NOT overwritten, merge by hand (${#conflicts[@]}):"
  printf '  %s\n' ${conflicts[@]+"${conflicts[@]}"}
fi
