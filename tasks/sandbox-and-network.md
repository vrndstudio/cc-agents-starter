# Sandbox & network: model, decisions, rationale

2026-11-01, `offfeed`. Settings keys verified against code.claude.com docs. What to apply:
`provisioning-changes.md`.

## Layers

All layers a request touches must allow it.

| # | Layer | Config | Scope | Agent can change? |
|---|-------|--------|-------|-------------------|
| 1 | Permission rules | `settings.json` → `permissions.allow/ask/deny` | every tool call | no (D11) |
| 2 | Bash sandbox (bubblewrap) | `settings.json` → `sandbox.*` + Read/Edit/WebFetch rules merged in | Bash + children | no (D10, D11) |
| 3 | sbx VM firewall | host: `sbx policy …` | all VM egress | no (outside VM) |
| + | Auto-mode classifier | — | risky calls | — |

- Precedence: deny > ask > allow. A bare `deny: ["WebFetch"]` beats every `WebFetch(domain:…)` allow.
- Auto mode skips prompts for tools with no matching rule. Without rules, WebFetch reaches any domain sbx allows.
- `Read(...)` deny rules also feed the sandbox `denyRead`, so they block `cat` too. `Edit(...)` deny rules don't cover shell writes; the sandbox's read-only mounts do.

## Why keep layer 2 with sbx (D1)

| Without bubblewrap | Why sbx doesn't catch it |
|---|---|
| Bash writes `~/.claude/settings.json`, `~/.claude.json`, hooks → self-grants permissions | in-VM, no egress |
| `cat ~/.ssh/*`, credentials | in-VM; `Read(...)` denies only the Read tool |
| any sbx-allowed host reachable from any command | sbx is per-VM, not per-command |

Cost of keeping it: cache write paths + domain allowlist (D4, D5).

## Issues hit

| Failure | Layer | Fix |
|---|---|---|
| `corepack prepare pnpm@10` → `EROFS ~/.cache/node/corepack` | 2 fs | D4 |
| same, `registry.npmjs.org` blocked | 2 net | D5 |
| `dangerouslyDisableSandbox` retry denied | classifier | D2 (hatch removed) |
| `claude mcp add` not saved (`~/.claude.json` RO) | 2 fs | intended; do from host (D8) |
| `chmod ~/.claude/statusline.sh` RO | 2 fs | harmless; ship file (P2) |
| `claude mcp list` → `api.anthropic.com` denied | 2 net | cosmetic; use `/mcp` |
| `mcp.exa.ai` → `403 Approval required` | 3 | D9 |
| `mcp-gateway.docker.internal` blocked | 2 + 3 | open (O1) |
| project `.mcp.json` "Failed to parse" | provisioning | intended: project `.claude/*`, `.mcp.json` masked to `/dev/null` |
| no web search | 1 | D6, D7, D8 |
| Edit tool could modify `~/.claude/settings.json` (classifier-gated only) | 1 | D11 |
| classifier refused agent removing WebSearch/WebFetch denies | classifier | intended; user edits (D12) |

## Parameters

### Layer 1

| Rule | Effect / risk |
|---|---|
| `WebFetch(domain:x)` allow | no prompt for `x`; `*.x` excludes apex |
| `ask: ["WebFetch"]` | other domains prompt (default mode); auto mode → layer 3 holds |
| `WebSearch` | runs Anthropic-side, no VM egress; query text can leak |
| `mcp__exa__*` | same leak + third party (Exa); needs `mcp.exa.ai` at layer 3 |
| `Bash(curl:*)`/`wget` deny | speed bump only (`node -e fetch`); layers 2/3 are real control |

### Layer 2

| Key | Value | Effect / risk |
|---|---|---|
| `enabled` | `true` | — |
| `failIfUnavailable` | `true` | no silent unsandboxed fallback |
| `allowUnsandboxedCommands` | `false` | strict: `dangerouslyDisableSandbox` ignored |
| `autoAllowBashIfSandboxed` | `false` | `true` = no Bash prompts; denies still apply |
| `excludedCommands` | unset | runs unsandboxed; don't use as shortcut |
| `filesystem.allowWrite` | caches only | never `~/.claude*`, shell rc |
| `network.allowedDomains` | registries + GitHub | each writable host = exfil channel |
| `network.deniedDomains` | gist, uploads | beats allowedDomains |

### Layer 3

| Command | Effect |
|---|---|
| `sbx policy allow network <d>` | all sandboxes |
| `… --sandbox <name> <d>` | one sandbox |
| `… "**"` | ⚠️ layer 3 gone |
| unallowed | approval prompt (`sbx policy approval ls`) |
| `sbx policy log` | audit contacted hosts |

## Threat model

- Main risk: prompt injection via fetched page or search result.
- Damage = readable secrets × writable endpoints.
- Mitigations: credential `denyRead`; agent can't read or write its own config (D10, D11); allowlists at layer 3; writable hosts (gist, uploads) denied.

## Decisions

Status: ✅ applied · 🟡 user applying · ⬜ provisioning. `P#` = item in `provisioning-changes.md`.

| # | Decision | Setting | Status |
|---|----------|---------|--------|
| D1 | Keep bash sandbox despite sbx | `sandbox.enabled: true` | ✅ |
| D2 | Strict mode | `allowUnsandboxedCommands: false` | ✅ |
| D3 | Fail if bubblewrap missing | `failIfUnavailable: true` | ✅ |
| D4 | Bash writes caches only | `allowWrite`: corepack, pnpm, uv caches | ✅ |
| D5 | Bash net: registries + GitHub, no gist/uploads | `allowedDomains` / `deniedDomains` | ✅ |
| D6 | Search: Exa first, WebSearch fallback | allow `mcp__exa__*`, `WebSearch`; drop `WebSearch` deny. Order set by global CLAUDE.md | 🟡 |
| D7 | Fetch: domain allowlist, rest prompts | drop bare `WebFetch` deny; allow `WebFetch(domain:…)`; `ask: ["WebFetch"]` | 🟡 (`ask` ✅) |
| D8 | Exa MCP, user scope, from host | `claude mcp add --scope user …` | ✅ here · ⬜ P3 |
| D9 | Layer 3 global; mirror fetch domains (auto mode skips prompts) | `sbx policy allow network …` | `mcp.exa.ai` ✅ · rest ⬜ P5 |
| D10 | `~/.claude*` unwritable from Bash | sandbox default | ✅ |
| D11 | Agent can't Read/Edit own settings | deny `Read`/`Edit` on `~/.claude/settings.json`, `~/.claude/settings.local.json`, `~/.claude.json` | ✅ |
| D12 | User edits settings outside the agent | VS Code Remote-SSH → `offfeed.sbx` (after `sbx setup ssh`); or `sbx cp` out/in; UI `/permissions`, `/sandbox`, `/config`. Never symlink into workspace (agent-writable) | ✅ · P4 |

Strict-mode consequences:
- Anything writing `~/.claude*` or reaching a non-allowlisted host is done at provisioning or from the host.
- A new cache path needs a new `allowWrite` entry, not `excludedCommands`.
