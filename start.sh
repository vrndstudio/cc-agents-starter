#!/usr/bin/env bash
# start.sh — create or reopen a sandbox for a project, provision it, attach.
#
#   ./start.sh <project>
#
# Run this from ANY folder. The only path that matters is the argument: that
# is the project the sandbox will work on. This script's own location matters
# only because setup.sh and claude/ live next to it.
#
# For code you don't trust, add --clone to the sbx create line below: your
# files become read-only to the sandbox and Claude works on a private copy.
set -euo pipefail

# Canonical absolute path. Fails fast if the folder doesn't exist.
PROJECT="$(cd "${1:-$PWD}" && pwd -P)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sandbox name defaults to the project folder name. Override when two projects
# share a folder name, or to target an existing sandbox:
#   SBX_NAME=my-sandbox ./start.sh <project>
NAME="${SBX_NAME:-$(basename "$PROJECT")}"

# The sandbox mirrors this exact path internally, so a username in it leaks
# into logs, stack traces and source maps.
case "$PROJECT" in
  *"$(whoami)"*)
    echo "warning: '$PROJECT' contains your username, which is mirrored inside"
    echo "         the sandbox and into any paths it prints."
    ;;
esac

# Exact match on the name column. Plain 'grep -w site' would also match
# 'site-2', which would silently skip creation.
sandbox_exists() {
  sbx ls 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$1"
}

# --- create or reopen ------------------------------------------------------
# This is the only command that cares about the project path. It binds the
# project to the sandbox permanently. Everything after this finds the sandbox
# by name.
if sandbox_exists "$NAME"; then
  echo "Reopening sandbox: $NAME"
else
  echo "Creating sandbox '$NAME' for: $PROJECT"
  sbx create --name "$NAME" claude "$PROJECT"
fi

# --- credentials -----------------------------------------------------------
# Tokens are scoped to one sandbox with --sandbox:
#   pbpaste | sbx secret set github --sandbox "$NAME"
#
# Without --sandbox, a secret is global: injected into EVERY sandbox at
# creation, including throwaways for repos you don't trust. The proxy hides a token's value from
# the agent but not its capability, so one global token means any compromised
# sandbox can act as you on every repo that token covers. Scoping per sandbox
# keeps the blast radius to one project.
#
# Scoped secrets can also be replaced on a running sandbox, so rotating an
# expiring token costs nothing. Global ones only inject at creation, which
# means a full rebuild.
#
# This runs after create because a sandbox has to exist before a secret can be
# scoped to it.
# 'sbx secret ls' columns: SCOPE TYPE NAME SECRET, indented.
has_github_secret() {
  sbx secret ls 2>/dev/null |
    awk -v scope="$1" '$1 == scope && $3 == "github" {found = 1} END {exit !found}'
}

if ! has_github_secret "$NAME"; then
  read -rp "No GitHub token for '$NAME'. Set one from the clipboard now? [y/N] " ans
  case "${ans:-n}" in
    [yY]) pbpaste | sbx secret set github --sandbox "$NAME" ;;
    *)    echo "skipped. Set it later with:  pbpaste | sbx secret set github --sandbox $NAME" ;;
  esac
fi

# --- provision once --------------------------------------------------------
# setup.sh and claude/ are bundled and copied in. They are NOT mounted: this is
# a one-off copy into /tmp inside the sandbox. Guarded by a marker file, so it
# only runs the first time.
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
# First time only: type  /login  inside Claude and pick
# "Claude account with subscription".
exec sbx run --name "$NAME"