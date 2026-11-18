# <project name>

<One paragraph: what this is, who uses it, what must never break.>

## Commands

- Install: `<pnpm install>`
- Dev server: `<pnpm dev>` (http://localhost:<port>)
- Verify everything: `scripts/verify` (must exit 0 before you say done)
- UI exploration: `bombadil browser test --headless --exit-on-violation --time-limit 2m http://localhost:<port> bombadil/specification.ts`

## Map

- `<src/domain>`: pure business logic, no I/O
- `<src/api>`: boundary; parse and validate here
- `<src/ui>`: components

## Rules for this repo

The global rules (RULES.md, GUIDE.md from zynchro/dev) apply. Repo-specific ones:

- <e.g. all money is integer minor units>
- <e.g. every user-facing string goes through i18n, and layouts must work RTL>

## Done means

`scripts/verify` exits 0, the change was exercised on the real surface, and the evidence is in your reply or PR body.
