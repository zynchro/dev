---
name: bombadil
description: Property-based exploration testing of web UIs (and experimental terminal UIs) with Antithesis Bombadil. Use after changing a web UI, when hunting crashes, console errors, HTTP errors, leaks or broken state, or when adding UI invariants to CI or a nightly run.
---

# Bombadil

Bombadil drives a real Chrome through your app with random clicks, inputs, navigation, back, forward and reload, and checks properties on every state. It finds what example-based tests miss: crashes, console errors, failed requests, leaks and broken invariants.

Check it's installed with `bombadil --version`; if not, download the release binary for your platform from github.com/antithesishq/bombadil/releases, verify its SHA-256, and put it on PATH. It uses Google Chrome from `/Applications`, or the path in `$CHROME`.

## Quick smoke run (no spec needed)

```bash
bombadil browser test --headless --exit-on-violation --time-limit 2m \
  --output-path .bombadil/run http://localhost:3000
```

Always pass `--time-limit`; without it the run never ends. Exit codes: `0` no violation, `2` property violated, `1` other error.

The default properties are `noConsoleErrors`, `noHttpErrorCodes`, `noUncaughtExceptions` and `noUnhandledPromiseRejections`. If the app legitimately returns 401 or 404, write a spec that exports only the properties you want.

## Writing a spec

Put it at `bombadil/specification.ts`:

```ts
import { extract, always, now, eventually } from "@antithesishq/bombadil";
export * from "@antithesishq/bombadil/browser/defaults";

const title = extract((state) => state.document.title || "");
export const hasTitle = always(() => title.current !== "");

const errorBanner = extract((state) =>
  state.document.body.querySelector("[role=alert]")?.textContent ?? null);
export const errorsClear = always(
  now(() => errorBanner.current !== null).implies(
    eventually(() => errorBanner.current === null).within(5, "seconds")));
```

- The module may export only properties and action generators; export names show up in violation reports.
- `extract` runs in the browser and must return JSON-serializable data; read it with `.current`.
- Combine formulas with `always`, `eventually`, `next`, `.and`, `.or`, `.implies`, `not()`.
- Restrict or weight actions with `actions`, `weighted`, `.filter`, `.when`. Export only the filtered generator.
- Log in or set up state with `registerCustomAction`, or pass `--cookie` / `--header`.
- Leak checks: `noResourceLeak({ metric: "dom_nodes" })` from `@antithesishq/bombadil/browser/extras/resources`. Prefer `dom_nodes` or `js_event_listeners` over the noisy JS heap.
- The spec runtime is not Node. Packages that import Node modules will not load.
- For types, `npm install --save-dev @antithesishq/bombadil` in the project.

Run it:

```bash
bombadil browser test --headless --exit-on-violation --time-limit 2m \
  --output-path .bombadil/run http://localhost:3000 bombadil/specification.ts
```

## When it finds something

1. `bombadil browser inspect .bombadil/run` opens a timeline with screenshots and extracted values. Use `--no-open` on a headless machine.
2. Reproduce with the same options: `bombadil browser test --reproduce .bombadil/run/trace.jsonl <url> bombadil/specification.ts` (no `--time-limit` or `--exit-on-violation` here). Bombadil prints the exact command after a run; prefer that.
3. Turn the minimal sequence into a regression test (Playwright or a Bombadil property) before fixing it.
4. Use a fresh `--output-path` per run, or pass `--output-path-overwrite`.

## Where it fits

- After any UI change: a 1 to 2 minute smoke run against the dev server.
- In PRs: `antithesishq/bombadil-action@v2` against the preview URL, 5 minutes.
- Nightly: long runs against staging (Hermes on zynch-mini can schedule these).
- Terminal UIs: `bombadil terminal test --specification tui.spec.ts --time-limit 1m <command>` (experimental).

It complements fast-check (domain invariants) and Playwright journeys (known paths). It replaces neither.
