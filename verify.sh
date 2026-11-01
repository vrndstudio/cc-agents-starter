#!/usr/bin/env bash
# verify.sh — check what actually got installed in a sandbox.
#
#   ./verify.sh <sandbox-name>
set -euo pipefail

NAME="${1:?usage: ./verify.sh <sandbox-name>}"

sbx exec -it "$NAME" bash -lc '
  version() { command -v "$1" >/dev/null && "$@" 2>&1 | head -1 || echo MISSING; }
  echo "--- tools ---"
  echo "git:    $(git config --global user.name) <$(git config --global user.email)>"
  echo "node:   $(version node -v)"
  echo "pnpm:   $(version pnpm -v)"
  echo "rg:     $(version rg --version)"
  echo "fzf:    $(version fzf --version)"
  echo "jq:     $(version jq --version)"
  test -f "$HOME/.setup-done" && echo "marker: set" || echo "marker: MISSING"

  echo
  echo "--- claude config ---"
  ls -la "$HOME/.claude" 2>/dev/null || echo "no ~/.claude"

  echo
  echo "--- isolation check: what crossed from the host? ---"
  mount | grep -iE "9p|virtiofs" || findmnt -o TARGET,SOURCE,FSTYPE 2>/dev/null | head -20
  echo "your Mac home:  $(ls /Users 2>&1 | head -1)"
  echo "ssh keys:       $(ls ~/.ssh 2>&1 | head -1)"

  echo
  echo "--- plugins ---"
  claude plugin list

  echo
  echo "--- marketplaces ---"
  claude plugin marketplace list

  echo
  echo "--- user-level skills ---"
  ls -1 ~/.claude/skills/ 2>/dev/null || echo "none"
'
