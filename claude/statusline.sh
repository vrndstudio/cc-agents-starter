#!/usr/bin/env bash
# Claude Code status line: model │ branch[*] │ ctx N% │ 5h N% (resets HH:MM)
# All numbers come from the JSON Claude Code passes on stdin.
# 5h usage only shows on a Claude subscription, after the first reply.
set -euo pipefail

input="$(cat)"
field() { jq -r "$1 // empty" <<<"$input"; }

model="$(field .model.display_name)"
dir="$(field .workspace.current_dir)"
ctx="$(field .context_window.used_percentage)"
five="$(field .rate_limits.five_hour.used_percentage)"
resets="$(field .rate_limits.five_hour.resets_at)"

out="${model:-?}"

if branch="$(git -C "${dir:-.}" symbolic-ref --short -q HEAD 2>/dev/null)"; then
  [ -n "$(git -C "${dir:-.}" status --porcelain 2>/dev/null | head -1)" ] && branch+="*"
  out+=" │ $branch"
fi

[ -n "$ctx" ] && out+=" │ ctx $(printf '%.0f' "$ctx")%"

if [ -n "$five" ]; then
  out+=" │ 5h $(printf '%.0f' "$five")%"
  [ -n "$resets" ] && out+=" (resets $(date -d "@$resets" +%H:%M))"
fi

printf '%s\n' "$out"
