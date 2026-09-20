#!/bin/sh
# Compute the git state the panels render, and write it to the cache as two files.
#
# This exists so that rendering never spawns a process. init.lua used to call git
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
# A function, not a command string. `G="git -C $ROOT"` expanded unquoted at every call
# site, so the repo path was word-split and glob-expanded: a path containing a space -
# routine on macOS - made every git call fail, the script wrote neither cache file and
# still exited 0, and a path crafted to split into `-c core.fsmonitor=...` could inject
# a global git option that git runs through a shell. As a function the path is always
# one quoted argument.
g() { git -C "$ROOT" "$@"; }

# Both temp files are cleaned up on any exit, not just the happy path.
TMP=""
trap 'rm -f "$TMP"; rmdir "$LOCK" 2>/dev/null' EXIT INT TERM HUP

TMP=$(mktemp "$OUT.XXXXXX") || exit 0
g status --porcelain --ignored -z > "$TMP" 2>/dev/null || { rm -f "$TMP"; exit 0; }
# A failed rename must abort: writing .meta afterwards would stamp a fresh ts onto a
# stale .status and advertise it as current, which is the one thing the two-file
# ordering exists to prevent.
mv -f "$TMP" "$OUT.status" 2>/dev/null || { rm -f "$TMP"; exit 0; }

TMP=$(mktemp "$OUT.XXXXXX") || exit 0
{
  # printf, not echo: where /bin/sh is dash, echo expands backslash escapes, so a commit
  # subject containing a literal \n would inject extra lines into the cache and could
  # forge a `branch` line.
  printf 'ts %s\n' "$(date +%s)"

  # symbolic-ref, not rev-parse --abbrev-ref: the latter prints the literal "HEAD"
  # for a detached or unborn head, so the panel title read "(HEAD)". Detached shows
  # the short sha instead, which is what you actually want to see there.
  BRANCH=$(g symbolic-ref --short -q HEAD 2>/dev/null)
  [ -n "$BRANCH" ] || BRANCH=$(g rev-parse --short HEAD 2>/dev/null)
  [ -n "$BRANCH" ] && printf 'branch %s\n' "$BRANCH"

  # Ahead/behind is only meaningful against the tracked branch, so it stays on @{u}
  # and is simply absent when there is no upstream. Raw counts - init.lua formats them.
  AB=$(g rev-list --left-right --count "@{u}...HEAD" 2>/dev/null)
  [ -n "$AB" ] && printf 'ab %s\n' "$AB"

  # A commit not reachable from any remote-tracking branch is local / not yet pushed.
  # `--not --remotes` rather than `@{u}..HEAD` so a branch you have never pushed still
  # marks its commits as local. With no remotes at all we cannot tell what is pushed,
  # so nothing is marked.
  if [ -n "$(g rev-list --remotes -n1 2>/dev/null)" ]; then
    printf 'remotes 1\n'
    g rev-list HEAD --not --remotes 2>/dev/null | while IFS= read -r sha; do
      printf 'unpushed %s\n' "$sha"
    done
  else
    printf 'remotes 0\n'
  fi

  g log --format="%H%x09%s%x09%an" -n 100 2>/dev/null | while IFS= read -r line; do
    printf 'log %s\n' "$line"
  done
} > "$TMP" 2>/dev/null
mv -f "$TMP" "$OUT.meta" 2>/dev/null || rm -f "$TMP"
