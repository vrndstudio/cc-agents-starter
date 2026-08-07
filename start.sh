#!/usr/bin/env bash
# start.sh — open a safe, separate space for Claude Code to work in.
#
# Usage: ./start.sh [folder]
#   folder   the project to work on (defaults to the folder you're in)
#
# Add --clone to the create line below for code you don't trust: your files
# are then read-only to the sandbox and Claude works on a private copy.
set -euo pipefail

# Canonical path. Fails fast if the folder doesn't exist, and resolves
# relative paths so sbx always gets an absolute one.
PROJECT="$(cd "${1:-$PWD}" && pwd -P)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(basename "$PROJECT")"

# The sandbox mirrors this exact path internally, so a username in it ends up
# in logs, stack traces and source maps.
case "$PROJECT" in
  *"$(whoami)"*)
    echo "warning: '$PROJECT' contains your username, which will be mirrored"
    echo "         inside the sandbox and into logs. Consider /opt/sbx/<project>."
    ;;
esac

# Exact match on the name column. Plain grep -w would match 'site' inside
# 'site-2', silently skipping creation.
sandbox_exists() {
  sbx ls 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$1"
}

# --- create or reopen ------------------------------------------------------
if sandbox_exists "$NAME"; then
  echo "Reopening your space: $NAME"
else
  echo "Creating a new space for: $PROJECT"
  sbx create --name "$NAME" claude "$PROJECT"
fi

# --- credentials -----------------------------------------------------------
# Secrets are scoped per sandbox on purpose, using the positional form:
#   pbpaste | sbx secret set "$NAME" github
#
# Global (-g) secrets are injected into EVERY sandbox at creation, including
# throwaways you spin up for repos you don't trust. The proxy hides a token's
# value from the agent but not its capability, so a global token means any
# compromised sandbox can act as you on every repo the token covers. Scoping
# per sandbox keeps that blast radius to one project.
#
# Scoped secrets can also be set or replaced on a running sandbox, so rotating
# an expiring PAT costs nothing. Global ones only inject at creation, which
# means a rebuild.
#
# This runs after create because a sandbox must exist before a secret can be
# scoped to it.
if ! sbx secret ls 2>/dev/null | grep -q "^$NAME[[:space:]].*github"; then
  read -rp "No GitHub token for '$NAME'. Set one from the clipboard now? [y/N] " ans
  if [ "${ans:-n}" = "y" ] || [ "${ans:-n}" = "Y" ]; then
    pbpaste | sbx secret set "$NAME" github
  else
    echo "skipping. Set it later with:  pbpaste | sbx secret set $NAME github"
  fi
fi

# --- provision once --------------------------------------------------------
# Bundle the setup script and your Claude config so directories travel in one
# go and only a single file transfer has to work.
TMP="$(mktemp -d)"
tar czf "$TMP/provision.tgz" -C "$HERE" setup.sh claude
sbx cp "$TMP/provision.tgz" "$NAME:/tmp/provision.tgz"
rm -rf "$TMP"

sbx exec "$NAME" bash -lc '
  mkdir -p /tmp/provision
  tar xzf /tmp/provision.tgz -C /tmp/provision
  test -f "$HOME/.setup-done" || bash /tmp/provision/setup.sh
'

# --- attach ----------------------------------------------------------------
# First time only: type  /login , pick "Claude account with subscription".
exec sbx run --name "$NAME"