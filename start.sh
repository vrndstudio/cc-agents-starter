#!/usr/bin/env bash
# start.sh — open a safe, separate space for Claude Code to work in.
#
# Usage: ./start.sh [folder]
#   folder   the project you want to work on (defaults to the folder you're in)
#
# The space is a walled-off mini computer. Claude can work on your project
# inside it, but it can't reach the rest of your Mac.
set -euo pipefail

PROJECT="${1:-$PWD}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(basename "$PROJECT")"

# If you want Claude to work with GitHub, save a token once before starting:
#   echo "$(gh auth token)" | sbx secret set -g github
sbx secret ls 2>/dev/null | grep -qi github \
  || echo "note: no GitHub token saved. To let Claude use GitHub, run once:  echo \"\$(gh auth token)\" | sbx secret set -g github"

# Make the space the first time, or just reopen it after that.
if sbx ls 2>/dev/null | grep -qw "$NAME"; then
  echo "Reopening your space: $NAME"
else
  echo "Creating a new space for: $PROJECT"
  sbx create --name "$NAME" claude "$PROJECT"
fi

# Get the space ready once (adds a few tools and a name for saved changes).
sbx cp "$HERE/setup.sh" "$NAME:/tmp/setup.sh"
sbx exec "$NAME" bash -lc 'test -f "$HOME/.setup-done" || bash /tmp/setup.sh'

# Open Claude Code inside the space.
# First time only: type  /login , pick "Claude account with subscription",
# copy the web address into your browser, sign in, and paste the code back.
exec sbx run --name "$NAME"
