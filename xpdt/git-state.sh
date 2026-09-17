#!/bin/sh
# Compute the git state the panels render, and write it to the cache as two files.
#
# This exists so that RENDERING never spawns a process. init.lua used to call git
# directly from the Dynamic render functions (io.popen inside a draw call), so the
# first keypress after a cache TTL expired paid for `git status --ignored` plus five
# more git invocations before xplr could paint a frame - a visible stall every time
# you came back to the window. Now a detached run of this script refreshes the cache
# and the render functions only read files.
#
# Args: ROOT OUTBASE
#   ROOT     the git repo top level
#   OUTBASE  path prefix for the two output files (the caller owns the naming):
#            OUTBASE.status - raw `git status --porcelain --ignored -z` bytes.
#                             Kept raw and NUL-separated because that is what makes
#                             spaced and non-ASCII filenames work (see init.lua); a
#                             line-based format would re-break them.
#            OUTBASE.meta   - line-based, every value newline-free by construction
#                             (git refs cannot contain newlines and %s is a single
#                             line), so Lua can parse it without a JSON reader:
#                               ts <epoch>
#                               branch <name>
#                               ab <behind> <ahead>     (only with an upstream)
#                               remotes 0|1
#                               unpushed <sha>          (repeated)
#                               log <sha>\t<subject>\t<author>  (repeated)
#
# Both files are written to a temp file and moved into place, so a reader never sees
# a half-written cache. .status is written first and .meta (which carries the
# timestamp) last, so a torn read looks stale rather than fresh and simply refreshes
# again.
set -u
ROOT=${1:?}
OUT=${2:?}

command -v git >/dev/null 2>&1 || exit 0
[ -d "$ROOT" ] || exit 0

DIR=$(dirname "$OUT")
mkdir -p "$DIR" 2>/dev/null || exit 0

# One refresh at a time per repo. mkdir is the portable atomic test-and-set; a lock
# left behind by a killed run is cleared once it is over a minute old (-mmin +1 is
# the same on BSD and GNU find).
LOCK="$OUT.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null
    mkdir "$LOCK" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM HUP

G="git -C $ROOT"

TMP=$(mktemp "$OUT.XXXXXX") || exit 0
$G status --porcelain --ignored -z > "$TMP" 2>/dev/null || { rm -f "$TMP"; exit 0; }
mv -f "$TMP" "$OUT.status" 2>/dev/null || rm -f "$TMP"

TMP=$(mktemp "$OUT.XXXXXX") || exit 0
{
  echo "ts $(date +%s)"

  BRANCH=$($G rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$BRANCH" ] && echo "branch $BRANCH"

  # Ahead/behind is only meaningful against the tracked branch, so it stays on @{u}
  # and is simply absent when there is no upstream. Raw counts - init.lua formats them.
  AB=$($G rev-list --left-right --count "@{u}...HEAD" 2>/dev/null)
  [ -n "$AB" ] && echo "ab $AB"

  # A commit not reachable from ANY remote-tracking branch is local / not yet pushed.
  # `--not --remotes` rather than `@{u}..HEAD` so a branch you have never pushed still
  # marks its commits as local. With no remotes at all we cannot tell what is pushed,
  # so nothing is marked.
  if [ -n "$($G rev-list --remotes -n1 2>/dev/null)" ]; then
    echo "remotes 1"
    $G rev-list HEAD --not --remotes 2>/dev/null | while IFS= read -r sha; do
      echo "unpushed $sha"
    done
  else
    echo "remotes 0"
  fi

  $G log --format="%H%x09%s%x09%an" -n 100 2>/dev/null | while IFS= read -r line; do
    echo "log $line"
  done
} > "$TMP" 2>/dev/null
mv -f "$TMP" "$OUT.meta" 2>/dev/null || rm -f "$TMP"
