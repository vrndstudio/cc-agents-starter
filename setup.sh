#!/usr/bin/env bash
# setup.sh — runs INSIDE the sandbox, once. start.sh copies it in and runs it.
#
# It runs through 'sbx exec', outside Claude's bash sandbox, so it can write
# ~/.claude* and reach hosts that the agent itself can't.
#
# Every step checks for its own tool, so something already present in the base
# image never blocks the rest from installing.
set -euo pipefail

PROVISION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exact pins. Bump deliberately, after checking the release notes.
COREPACK_VERSION="__COREPACK__"
PNPM_VERSION="__PNPM__"
AST_GREP_VERSION="__AST_GREP__"
PREK_VERSION="__PREK__"
OXLINT_VERSION="__OXLINT__"
OXFMT_VERSION="__OXFMT__"

# ---------------------------------------------------------------------------
# 1. Neutral git identity.
#    Set globally inside the sandbox so the agent's commits are labelled 'dev'
#    without rewriting your project's own .git/config on the host.
# ---------------------------------------------------------------------------
git config --global user.name "dev"
git config --global user.email "dev@localhost"
git config --global init.defaultBranch main

# ---------------------------------------------------------------------------
# 2. Command line tools from apt. Checked individually, installed in one pass.
#    fd-find installs its binary as 'fdfind'; step 3 adds the 'fd' name.
# ---------------------------------------------------------------------------
missing=()
command -v rg >/dev/null 2>&1 || missing+=(ripgrep)
command -v fzf >/dev/null 2>&1 || missing+=(fzf)
command -v jq >/dev/null 2>&1 || missing+=(jq)
command -v fdfind >/dev/null 2>&1 || missing+=(fd-find)
command -v shellcheck >/dev/null 2>&1 || missing+=(shellcheck)
command -v shfmt >/dev/null 2>&1 || missing+=(shfmt)
command -v trash >/dev/null 2>&1 || missing+=(trash-cli)
command -v nano >/dev/null 2>&1 || missing+=(nano)

if [ ${#missing[@]} -gt 0 ]; then
  echo "installing: ${missing[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y "${missing[@]}"
fi

if ! command -v fd >/dev/null 2>&1; then
  sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

# ---------------------------------------------------------------------------
# 3. pnpm. The image's corepack (Debian 0.24.0) can't run current pnpm, which
#    ships bin/pnpm.mjs instead of .cjs. Install a newer corepack under
#    /usr/local, which comes first on PATH, claude. pin pnpm.
#    'corepack prepare' runs as you so the download lands in your own cache.
# ---------------------------------------------------------------------------
if [ "$(corepack --version 2>/dev/null)" != "$COREPACK_VERSION" ]; then
  sudo npm install -g --prefix /usr/local "corepack@$COREPACK_VERSION"
fi
sudo corepack enable pnpm
corepack prepare "pnpm@$PNPM_VERSION" --activate
pnpm --version

# ---------------------------------------------------------------------------
# 4. Linters and code tools, pinned.
#    ast-grep and prek go through uv (per-user, no sudo); oxlint and oxfmt
#    only ship on npm.
# ---------------------------------------------------------------------------
uv tool install "ast-grep-cli==$AST_GREP_VERSION"
uv tool install "prek==$PREK_VERSION"
sudo npm install -g --prefix /usr/local "oxlint@$OXLINT_VERSION" "oxfmt@$OXFMT_VERSION"

# ---------------------------------------------------------------------------
# 5. Your personal Claude config.
#    The sandbox cannot see ~/.claude from your Mac, so anything you want at
#    user level has to be placed here.
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude"

for f in settings.json CLAUDE.md statusline.sh; do
  cp "$PROVISION_DIR/claude/$f" "$HOME/.claude/$f"
  echo "installed ~/.claude/$f"
done
chmod +x "$HOME/.claude/statusline.sh"

# ---------------------------------------------------------------------------
# 6. Exa MCP, user scope. Must happen here: ~/.claude.json is read-only to the
#    agent. A paid key goes in as an sbx secret, never in this repo.
# ---------------------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  if ! claude mcp get exa >/dev/null 2>&1; then
    claude mcp add --scope user --transport http exa https://mcp.exa.ai/mcp
  fi
fi

# ---------------------------------------------------------------------------
# 7. Claude plugins, from claude/plugins.txt.
#    Failures are reported but don't abort the rest: plugin installs need
#    network access and sometimes need you to be logged in first.
# ---------------------------------------------------------------------------
PLUGINS_FILE="$PROVISION_DIR/claude/plugins.txt"

if [ -f "$PLUGINS_FILE" ] && command -v claude >/dev/null 2>&1; then
  while read -r marketplace plugin || [ -n "${marketplace:-}" ]; do
    case "$marketplace" in '' | \#*) continue ;; esac
    [ -n "${plugin:-}" ] || continue

    echo "adding marketplace: $marketplace"
    claude plugin marketplace add "$marketplace" || echo "  (already added, or add failed)"

    echo "installing plugin: $plugin"
    claude plugin install "$plugin" || echo "  could not install $plugin, add it by hand with /plugin"
  done <"$PLUGINS_FILE"
fi

touch "$HOME/.setup-done"
echo
echo "Setup complete."
