#!/bin/sh
# SOURCED, not executed:  . "$X/tmpflag.sh"
#
# Defines $XPDT_LEFT_EXIT, the flag file that tells flush-input.sh the program that
# just closed was left via a (possibly still-held) `left` key, so it should drain the
# key's auto-repeat instead of doing a one-shot flush. Every writer and the reader
# must agree on the path, so they all derive it here.
#
# It lives under $TMPDIR (per-user and mode 700 on macOS) and carries the user name,
# rather than sitting at a fixed /tmp path: on a shared machine a predictable name in
# a world-writable directory can be pre-created or symlinked by another user, which
# would at best break the drain and at worst redirect the write. $USER/$LOGNAME are
# exported by any login shell, so `id -u` is only a last-resort fallback (it costs a
# fork, and this is sourced on the file-open path).
XPDT_LEFT_EXIT="${TMPDIR:-/tmp}"
XPDT_LEFT_EXIT="${XPDT_LEFT_EXIT%/}/xpdt-left-exit-${USER:-${LOGNAME:-$(id -u 2>/dev/null || echo 0)}}"
export XPDT_LEFT_EXIT
