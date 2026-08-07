#!/usr/bin/env bash
# verify.sh — check what actually got installed in a sandbox.
#
#   ./verify.sh <sandbox-name>
set -euo pipefail

NAME="${1:?usage: ./verify.sh <sandbox-name>}"

sbx exec -it "$NAME" bash -lc '
  echo "--- tools ---"
  echo "git:    $(git config --global user.name) <$(git config --global user.email)>"
  echo "node:   $(node -v 2>/dev/null || echo MISSING)"
  echo "pnpm:   $(pnpm -v 2>/dev/null || echo MISSING)"
  echo "rg:     $(rg --version 2>/dev/null | head -1 || echo MISSING)"
  echo "fzf:    $(fzf --version 2>/dev/null || echo MISSING)"
  echo "jq:     $(jq --version 2>/dev/null || echo MISSING)"
  test -f "$HOME/.setup-done" && echo "marker: set" || echo "marker: MISSING"

  echo
  echo "--- claude config ---"
  ls -la "$HOME/.claude" 2>/dev/null || echo "no ~/.claude"
  claude plugin list 2>/dev/null || echo "(could not list plugins)"

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
