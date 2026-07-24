#!/bin/sh
# Print the git repository root for DIR (which may be, or sit under, a symlinked
# directory), treating a symlinked path component as belonging to the real
# directory that CONTAINS the symlink - not to wherever the symlink points. So
# entering a symlinked folder keeps the git context of where you entered it from
# instead of jumping to the git history of the symlink target's own repo.
#
# git -C <path> chdir()s into <path>, which resolves symlinks physically, so
# `git rev-parse --show-toplevel` on a symlinked location reports the target's repo.
# Instead, walk DIR's components along the *logical* path and find the deepest one
# that is itself a symlink; the "anchor" is that symlink's real parent directory.
# The repo is discovered from the anchor, so git resolves any symlinks ABOVE the
# anchor normally (e.g. a symlinked $HOME) - only the entered symlink and everything
# below it are excluded.
#
# Fallback: if the anchor is in no repo (e.g. you reached a repo BY following a
# symlink from a non-repo dir, like ~/.config/xpdt -> the xpdt checkout), fall back
# to the target's own repo so that case still shows git, exactly as before. This is
# never reached when the origin IS a repo, so it cannot re-introduce the hijack.
#
# Used by init.lua (the git panels) and the git browsers so they all agree on which
# repo a symlinked location belongs to.
dir="$1"
[ -n "$dir" ] || exit 0

anchor="$dir"
p=""
prev=""
IFS='/'
set -f
for comp in $dir; do
  [ -n "$comp" ] || continue
  prev="${p:-/}"
  p="$p/$comp"
  [ -L "$p" ] && anchor="$prev"
done
set +f
unset IFS

root=$(git -C "$anchor" rev-parse --show-toplevel 2>/dev/null)
if [ -z "$root" ] && [ "$anchor" != "$dir" ]; then
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
fi
[ -n "$root" ] && printf '%s\n' "$root"
