# Provisioning changes to upstream

From verifying `offfeed`, 2026-11-01. Rationale and decision IDs (`D#`): `sandbox-and-network.md`.

## Checklist

| # | Item | Where | Status here |
|---|------|-------|-------------|
| P1 | Fix pnpm (corepack too old) | image build | `setup.sh` §3 · versions pending |
| P2 | Ship `~/.claude/statusline.sh` | image files | `claude/statusline.sh` ✅ |
| P3 | Register Exa MCP | provisioning (host side) | `setup.sh` §6 ✅ |
| P4 | Settings editing path for user (D12) | host SSH setup; editor optional | README ✅ · `nano` in `setup.sh` |
| P5 | sbx network policy | host | by hand, gradually (not scripted) |
| P6 | `~/.claude/settings.json` | image files | `claude/settings.json` ✅ · D6/D7 untested in fresh sandbox |
| P7 | Missing CLI tools | image build | `setup.sh` §2, §4 · `wt` ⬜ |
| P8 | Settings cleanup | image files | ✅ |

## P1 pnpm

- Symptom: `pnpm --version` → `Cannot find module '~/.cache/node/corepack/pnpm/12.16.1/bin/pnpm.cjs'`
- Cause: `/usr/bin/pnpm` = Debian corepack 0.24.0. Unpinned, it fetches pnpm 12.16.1, which ships `bin/pnpm.mjs` instead of `.cjs`. pnpm 12 also downloads native `@pnpm/exe.<platform>` on first run.
- Fix (pick one, as `agent`):
  ```bash
  npm i -g corepack@<current-stable>   # look up + pin
  corepack enable pnpm
  # or
  corepack prepare pnpm@10.34.9 --activate   # version resolved here; pin exact
  ```
- Verify: `pnpm --version`; `~/.cache/node/corepack/lastKnownGood.json` names it.
- Do at build time. In-session, corepack works only via D4 (`~/.cache/node/corepack` writable) + D5 (`registry.npmjs.org`).

## P2 Status line

- `claude/statusline.sh`. Output: `model │ branch[*] │ ctx N% │ 5h N% (resets HH:MM)`.
- Data from Claude Code's stdin JSON (`context_window.used_percentage`, `rate_limits.five_hour`). Needs `jq`, `git`.

## P3 Exa MCP

```bash
claude mcp add --scope user --transport http exa https://mcp.exa.ai/mcp
```
- Paid key: `?exaApiKey=…` or auth header, injected as secret. Never commit.
- Must run outside the agent: `~/.claude.json` is RO to Bash and denied (D11).
- After first session: confirm tool names match allow list (`web_search_exa`, `web_fetch_exa`).

## P4 Settings editing (D12)

- Primary: host `sbx setup ssh` once → VS Code Remote-SSH → `<name>.sbx` → edit `/home/agent/.claude/settings.json`.
  - First connect downloads VS Code server into VM. If blocked: `sbx policy log`, allow the host. Untested.
- No-setup fallback:
  ```bash
  sbx cp <name>:/home/agent/.claude/settings.json ./settings.json
  sbx cp ./settings.json <name>:/home/agent/.claude/settings.json
  ```
- Optional: image has no `nano`/`vim`/`vi` for `sbx exec -it <name> bash`.

## P5 sbx policy (host)

```bash
sbx policy allow network mcp.exa.ai
sbx policy allow network registry.npmjs.org,pypi.org,files.pythonhosted.org,github.com,codeload.github.com
sbx policy allow network code.claude.com,docs.anthropic.com,developer.mozilla.org,nodejs.org,pnpm.io,raw.githubusercontent.com
```

## P6 `~/.claude/settings.json` (deltas from current upstream)

```jsonc
"sandbox": {
  "enabled": true,
  "failIfUnavailable": true,                // D3
  "allowUnsandboxedCommands": false,        // D2
  "autoAllowBashIfSandboxed": false,
  "filesystem": {                           // D4
    "allowWrite": ["~/.cache/node/corepack", "~/.cache/pnpm", "~/.local/share/pnpm", "~/.cache/uv"]
  },
  "network": {                              // D5
    "allowedDomains": [
      "registry.npmjs.org", "pypi.org", "files.pythonhosted.org", "github.com", "codeload.github.com"
    ],
    "deniedDomains": ["gist.github.com", "uploads.github.com"]
  }
},
"permissions": {
  "allow": [                                // + D6, D7
    "WebSearch",
    "WebFetch(domain:code.claude.com)",
    "WebFetch(domain:docs.anthropic.com)",
    "WebFetch(domain:developer.mozilla.org)",
    "WebFetch(domain:nodejs.org)",
    "WebFetch(domain:pnpm.io)",
    "WebFetch(domain:raw.githubusercontent.com)"
  ],
  "deny": [                                 // + D11; − "WebFetch", − "WebSearch"
    "Read(~/.claude/settings.json)",
    "Edit(~/.claude/settings.json)",
    "Read(~/.claude/settings.local.json)",
    "Edit(~/.claude/settings.local.json)",
    "Read(~/.claude.json)",
    "Edit(~/.claude.json)"
  ],
  "ask": ["WebFetch"]                       // + D7
}
```

## P7 Missing tools

- `trash`: hook + CLAUDE.md require it. Install `trash-cli` or change the hook message.
- CLAUDE.md expects: `fd`, `ast-grep`, `shellcheck`, `shfmt`, `oxlint`, `oxfmt`, `prek`, `wt`.
- `wt` (worktrunk) not installed: no cargo in image, no pinned install path chosen yet.

## P8 Cleanup (optional)

- macOS-only `~/Library/...` deny rules on a Linux image.
- Allow rules for absent tools: `bun`, `pnpm tailwindcss`.
- `Bash(claude mcp *)` allow: useless under D10/D11 (writes fail; `list` needs `api.anthropic.com`).

## Open

| # | Question |
|---|----------|
| O1 | `mcp-gateway` (`http://mcp-gateway.docker.internal/mcp`, 403 at layers 2 + 3): allow it or stop provisioning it? |
