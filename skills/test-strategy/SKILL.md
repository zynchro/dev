---
name: test-strategy
description: Choose which tests and checks a change needs across pre-production, deploy, release and post-release, and which tools to use. Use when planning tests for a feature or fix, setting up testing in a repo, or deciding whether a change is covered well enough to ship.
---

# Test strategy

Pick tests by risk, not by habit. For each change, answer three questions, then use the map below.

1. What breaks for a user if this is wrong?
2. Where would it break: logic, integration, UI, deploy, or only under real traffic?
3. What is the cheapest check that fails when it breaks and passes when internals change?

## The map

### Pre-production (on every change)

| Check | Use when | Tool |
|---|---|---|
| Static analysis, lint | always | tsc strict, oxlint `--type-aware`, knip, dependency-cruiser |
| Unit | pure logic with clear inputs and outputs | Vitest |
| Property-based | invariants: round-trips, ordering, idempotency, no crash on any input | fast-check |
| Component and integration | components in a real browser, services against a real DB | Vitest browser mode, Testcontainers |
| Contract | a boundary between independently deployed services | Zod or OpenAPI schemas plus Schemathesis; Pact only across teams |
| Exploration and fuzz | any web UI or TUI | Bombadil (`bombadil` skill) |
| Acceptance, end to end | the 5 to 20 journeys that make money or lose trust | Playwright Test, role locators |
| Regression | every fixed bug | the failing repro, kept as a test |
| Visual, UI/UX | key pages and states (empty, loading, error, long content, RTL) | Argos or Playwright screenshots, ARIA snapshots |
| Accessibility | every UI change | axe in Playwright, keyboard walk-through |
| Mutation | judging test strength on risky logic | Stryker, diff-only, report-only at first |
| Benchmark, performance | hot paths, page loads | Vitest bench, Lighthouse; report runs and spread |
| Security | dependencies, secrets, risky code paths | gitleaks, semgrep, `pnpm audit`; threat model for auth and payments |
| Formal verification | state machines or protocols where a bug is catastrophic | TLA+ or a model checker; rare |

Coverage is a floor that flags untested files, never a target.

### Deploy

| Check | Use when | How |
|---|---|---|
| Smoke | every deploy | Playwright `@smoke` journeys against the new environment |
| Config | env vars, feature flags, infra changes | validate config at startup and fail fast; diff rendered config |
| Integration on preview | every PR with a preview URL | Playwright and Bombadil against the preview |
| Load and soak | new endpoints with real traffic, or capacity changes | k6; soak for memory leaks over hours |
| Shadowing, tap compare | rewriting a service or algorithm | send copies of real traffic to old and new, diff the responses |

### Release

| Check | Use when | How |
|---|---|---|
| Feature flags | any risky or user-visible change | ship dark, enable per cohort, keep a kill switch |
| Canary | backend changes with traffic | small percentage first, compare error rate and latency |
| Exception tracking | always | Sentry or equivalent with release tags |
| Monitoring | always | dashboards and alerts on the golden signals |

### Post-release

| Check | Use when | How |
|---|---|---|
| Real user monitoring | web apps | Core Web Vitals and errors from real sessions |
| Tracing, logs and events | services | structured logs, OpenTelemetry traces with request ids |
| A/B tests | product decisions | only with a pre-registered metric and sample size |
| Dynamic exploration in prod | long-lived UIs | scheduled Bombadil runs against staging or prod (read-only flows) |
| Chaos | systems that claim resilience | kill a dependency on purpose, watch recovery |
| Auditing, on-call | always | runbooks, alert ownership, postmortems that add a check |

## Output

For the change at hand, write a short plan:

1. The risks (one line each).
2. The checks you will add or run, mapped to those risks, with the tool.
3. What you are deliberately not testing and why.

Then add the checks to `scripts/verify` or CI so they keep running. A check that only ran once on your machine protects nothing.
