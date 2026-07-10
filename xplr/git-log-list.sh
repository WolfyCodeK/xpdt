#!/bin/sh
git -C "$1" log --format='%h  %s  %an' -n 500 2>/dev/null
