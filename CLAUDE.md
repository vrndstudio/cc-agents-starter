## Context 

we are using Docker sandboxes (`sbx`). how do we make claude code workflow smoother while retaining tight security. how does claude gets access to specified plugins? 

don't try to bypass the sandbox blocks by trying multiple ways and waste tokens. 
[ specify the ways to use and prompting user to edit specific permissions or domains ]

# Goals

provision new sandbox created for a project in a specific directory. 

## Issues

the sandbox provisioning doesn't allow me to easily view and edit the ~/.claude files, which i like to do. as this is all evolving, i need to be able to easily do that. my preferred way is to do this is have access via the vscode explorer, from which i can open and edit files. let's find a proper solution for that, preferably one that is widely used. 

## Communication & documentation style

Compress every model response to telegraphic-style prose. Drop articles, filler, pleasantries, and hedging. Keep every technical detail (e.g. for code: code block, error string, and symbol exact). Cuts 65% of output tokens with full accuracy preserved. Mode persists for the whole session until changed or stopped.

Lead with the answer. No preamble, no summary of what you just said.
State uncertainty once, in 5 words or fewer. Bullets over prose. Fragments over sentences.

If a full answer needs length, give the short answer first and offer detail as a follow-up rather than volunteering it. Hard cap: 5 lines unless I ask to expand.

## Development workflow

This defines the agent-human collaboration flow for optimal development experience, splitting responsibilities and optimising tokens cost.

Claude may ask to use `agent-browser` CLI to drive browser checks. Don't use Playwright. otherwise:

**Human runs:**

- `pnpm dev` — long-running dev server; human keeps it open during UI work
- `pnpm build` — production build smoke test
- Browser smoke tests — visual checks, console inspection, theme toggle, navigation
- Prompts Claude back
- Edits on config and settings files

**Claude runs directly:**

- `pnpm typecheck` — TypeScript strict check
- `pnpm lint` — oxlint
- `pnpm test` — Vitest suite


## Open

- let's make sure the suggested @README.md commands have clear and understandable placeholders in the instructions so i can get back to them easily
- pickup @README.md inconsistencies, streamline copy based on doc style instructions above. 
- [later?] install bun and include it in setup.sh script

