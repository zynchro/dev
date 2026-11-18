# zynchro/dev

One set of engineering rules, testing skills and quality gates, installed into every coding agent I use: Claude Code, omp, Codex and Hermes. Clone it on any Mac, run one script, and every agent works to the same bar.

## Install

```bash
git clone https://github.com/zynchro/dev ~/Desktop/zynchro/dev
cd ~/Desktop/zynchro/dev
./install.sh --dry-run
./install.sh
./install.sh --check
```

On the work laptop, create only the work memory pool. The choice is remembered, so later plain runs and checks keep it:

```bash
./install.sh --pools noon
```

Rules and skills are linked, so `git pull` updates Claude Code and omp at once. Codex and Hermes get a generated copy: rerun `./install.sh` after a pull (`--check` tells you when they're stale).

Install is safe to rerun. Anything it replaces is moved to `~/.zynchro-backups/<timestamp>/` and config files it edits are copied there first. It never overwrites Hermes `coding_instructions` you wrote yourself. `./install.sh --uninstall` removes what it created and puts back what it moved; Hermes memory pools are kept.

## What goes where

| Piece | Claude Code | omp | Codex | Hermes |
|---|---|---|---|---|
| `rules/RULES.md` (hard rules) | `~/.claude/rules/zynchro-rules.md` | `~/.omp/agent/RULES.md` (also reaches subagents) | `~/.codex/AGENTS.md` (generated) | `agent.coding_instructions` (generated) |
| `rules/GUIDE.md` (how we build) | `~/.claude/rules/zynchro-guide.md` | `~/.omp/agent/AGENTS.md` | `~/.codex/AGENTS.md` (generated) | `agent.coding_instructions` (generated) |
| `skills/*` | `~/.claude/skills/` | `~/.agents/skills/` | `~/.agents/skills/` | `skills.external_dirs` includes `~/.agents/skills` |
| `hooks/claude/stop-verify.sh` | Stop hook in `~/.claude/settings.json` | | | |
| `hermes/pools.tsv` | | | | one Hermes profile per pool |

`~/.claude/CLAUDE.md` is left alone because oh-my-claudecode manages it.

## Skills

- `test-strategy`: which tests and checks a change needs, from pre-production to post-release, and which tools to use.
- `bombadil`: property-based exploration of web UIs with Antithesis Bombadil.
- `quality-gate`: prove a change works on the real surface before calling it done.
- `comment-review`: remove every comment that isn't on the keep list and fix the code that needed it.

## Memory pools

Each pool in `hermes/pools.tsv` is a Hermes profile with its own memory, sessions and skills, cloned from the default profile so it starts with the same model and keys. Talk to one with its alias, for example `zynch chat` or `hermes -p personal chat`.

Work memory (`noon`) lives only on the work laptop. This repo is public: it holds pool names and descriptions, never memory.

## Set up a repo

```bash
cp -Rn ~/Desktop/zynchro/dev/templates/project/. path/to/repo/
cd path/to/repo
git config zynchro.verify true
```

`cp -Rn` never overwrites files the repo already has. You get `AGENTS.md`, `scripts/verify` (the one command every gate runs), `lefthook.yml` and a starter `bombadil/specification.ts`.

The Claude Stop hook only acts in repos that opted in with `git config zynchro.verify true`, so it never runs a cloned repo's scripts on its own. In an opted-in repo with uncommitted changes, it runs `scripts/verify` before the agent may finish. A failure blocks the agent once; if the same code still fails, you get a warning that the answer is unverified. Results are cached per state of the code, so unchanged code is never verified twice.

## Develop

```bash
tests/install.test.sh
tests/stop-verify.test.sh
tests/verify-template.test.sh
shellcheck install.sh hooks/claude/stop-verify.sh templates/project/scripts/verify tests/*.sh tests/fake-hermes
```

CI runs the same on macOS, using the system bash 3.2 that macOS ships.
