#!/bin/sh
# Stash list for the browser. Field 1 is the stash ref (stash@{N}) that every
# operation keys off; the rest (relative date, then the reflog description) is
# human-facing. Tab-delimited from git so the awk split is unambiguous.
git -C "$1" stash list --format='%gd%x09%cr%x09%gs' 2>/dev/null \
  | awk -F '\t' '{ printf "\033[33m%-9s\033[0m  \033[90m%-13s\033[0m  %s\n", $1, $2, $3 }'
