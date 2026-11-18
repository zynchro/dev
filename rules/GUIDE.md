# Engineering guide (zynchro/dev)

How we build and ship. The hard rules live in RULES.md; this guide explains how to meet them.

## Code

- Name the data shape first, then write the code around it. Model states with discriminated unions, state machines or reducers instead of booleans that must stay in sync.
- Validate and parse at system boundaries (HTTP, files, env, queues, user input). Inside the boundary, trust the types; no re-validation and no defensive nil checks deep in call chains.
- Keep business logic in pure functions. Push I/O to the edges.
- Prefer boring, explicit code. Three similar lines beat a premature abstraction. Collapse wrappers with one caller and adapters with one implementation.
- Every mutating operation answers two questions: what if it runs twice, and what if it crashes halfway?
- Remove shared mutable state before reaching for locks.
- When replacing an API, migrate every caller and delete the old one in the same change. No compatibility shims or parallel old and new paths.
- TypeScript: `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`. Use `unknown`, not `any`. Use `satisfies` instead of casts that silence the type checker (`as const` is fine). Exhaustive `switch` ends in `const _exhaustive: never = x`. Derive types from schemas (`z.infer`). No `console.log` in shipped code.

## Comments

A comment survives only if it is on the keep list in RULES.md rule 4. Everything else goes:

- If code needs a comment to be understood, rename, extract or retype it until it doesn't.
- A comment that says "do not remove" or "important" is a missing check. Encode it as a type, a runtime assertion, a test or a lint rule, then delete the comment.
- Test and verify scripts document themselves through assertion messages and log strings, not phase comments.
- Have a fresh agent run the `comment-review` skill on the diff; authors defend their own comments.

## Testing

Use the `test-strategy` skill to pick tests for a change. The defaults:

| Layer | What it covers | Default tools |
|---|---|---|
| Static (widest) | types, lint, dead code, layer rules | tsc strict, oxlint `--type-aware`, knip, dependency-cruiser |
| Unit and property | domain logic, invariants | Vitest, fast-check |
| Integration (largest runtime layer) | components in a real browser, services against a real DB | Vitest browser mode, Testcontainers; MSW only for third-party APIs |
| Exploration | crashes, console errors, HTTP errors, leaks, state invariants | Bombadil (`bombadil` skill) |
| End to end (thin) | 5 to 20 key journeys | Playwright Test with role locators |
| Visual (thin) | key pages, ARIA snapshots | Argos or Playwright screenshots |

- Derive expected values from the requirement, never from running the code under test.
- A test is worth keeping if it fails when the behavior breaks and passes when internals change. Prefer no test over a test that pins implementation, depends on timing, or mostly tests mocks.
- Assert on the error type callers branch on, not on message wording.
- Before a refactor, pin behavior with a characterization or equivalence test. Type check and lint are not a pin.
- No ritual TDD. Bug fixes need a failing repro first. For features, write the acceptance scenarios first and get a human to approve them before an agent writes both tests and code.
- Measure test strength with mutation testing (Stryker, diff-only) rather than coverage. Coverage is a floor, not a goal.
- Never use fixed sleeps, `networkidle` or CSS/XPath locators in UI tests.

## Verification by change type

Pick the check that touches the real surface (`quality-gate` skill):

| Change | Proof |
|---|---|
| CLI or script | run the real command with real arguments; show output and exit code |
| UI | walk the flow in the running app; screenshot or Bombadil run |
| API | call the endpoint; show request, status and body |
| Parser or data transform | replay saved real inputs; diff the output |
| Storage or migration | write, then read back; run the migration on a copy of real data |
| Performance | before and after profiles with run count and spread |
| Config or infra | apply it, then observe the effect (service up, port open, job ran) |

When verification fails, suspect the observation method before the system. After two failed fixes on one premise, write the premise down and test it before trying a third fix.

## Quality gates

| Stage | Runs | Blocks? |
|---|---|---|
| While editing | lint and related tests for the touched file | feedback only |
| Agent stop | `scripts/verify` (Claude Stop hook, in repos with `git config zynchro.verify true`) | yes, once; after that the user is warned the answer is unverified |
| Pre-commit | gitleaks on staged files, plus the repo's formatter and linter (lefthook) | yes |
| Pre-push | `scripts/verify` | yes |
| PR fast lane | typecheck, lint, unit and property tests, knip, gitleaks, semgrep | yes |
| PR deep lane | Playwright on preview, visual diffs, Stryker on the diff, Bombadil smoke | yes; visual diffs need a human |
| Nightly | long Bombadil runs, full Stryker, flaky-test repeats, secret scans | opens issues |
| After deploy | smoke tests on prod, error tracking, alerts | triggers rollback |

Every repo gets a `scripts/verify` that exits non-zero on any failure, including a check it could not run. Copy `templates/project/` to start.

## Reviews and PRs

- The agent that wrote a change never approves it. Get an independent review (another agent or a human) before merging.
- Small ordered commits that read as an argument: failing test, then fix, then cleanup.
- A PR body states why, what changed, blast radius, and the verification evidence. Open it as ready only when that evidence is in the body; otherwise open a draft.
- One advisory AI review bot at most. Triage its comments; dismiss noise with a reason.

## Encode lessons

When the same mistake happens twice, make it impossible instead of writing another rule: architecture first, then types, then a lint rule whose message names the fix, then a test. Prove the new check fails on the real past mistake. Text rules are the last resort.

## Writing for people

Plain sentences, sentence-case headings, no filler, no hedging. Every claim carries its evidence or says whether it is measured, inferred or a guess.
