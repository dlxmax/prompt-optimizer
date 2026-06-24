#!/usr/bin/env bash
# Delete sibling plugin-cache version dirs older than the current one.
# Runs at SessionStart so the prior version is removed immediately after
# /plugin marketplace update installs a new one.
set -eu

parent="$(dirname "${CLAUDE_PLUGIN_ROOT:-}")"
current="$(basename "${CLAUDE_PLUGIN_ROOT:-}")"

[ -z "$parent" ] && exit 0
[ -z "$current" ] && exit 0
[ ! -d "$parent" ] && exit 0

shopt -s nullglob
for d in "$parent"/*/; do
  name="$(basename "$d")"
  [ "$name" = "$current" ] && continue
  case "$name" in
    [0-9]*.[0-9]*.[0-9]*) rm -rf "$d" ;;
  esac
done
