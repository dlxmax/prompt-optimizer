#!/usr/bin/env bash
# Delete sibling plugin-cache version dirs older than the current one.
# Runs at SessionStart (startup only), so the prior version is removed on the
# first fresh launch after /plugin marketplace update; /reload-plugins and
# resumed sessions do not trigger it.
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
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) continue ;;
  esac
  # Keep newer versions: an old session starting must not delete them.
  older="$(printf '%s\n%s\n' "$name" "$current" | sort -V | head -n1)"
  if [ "$older" = "$name" ]; then rm -rf "$d"; fi
done
