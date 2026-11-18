---
name: quality-gate
description: Prove a change works before calling it done. Use before saying a task is complete, before committing or opening a PR, and whenever you are about to claim something works, is fixed or passes.
---

# Quality gate

Run this before you say "done".

## 1. Run the repo's checks

- If `scripts/verify` exists, run it and read the whole output. It must exit 0.
- If it doesn't exist, run the repo's typecheck, lint and test commands (see `package.json`, `Makefile`, `pyproject.toml` or the README). Offer to create `scripts/verify` from the zynchro/dev template.
- Never edit a test, threshold or lint config to get green. If a check is wrong, stop and say so.

## 2. Prove it on the real surface

Pick the proof for the change type and actually do it:

| Change | Proof |
|---|---|
| CLI or script | run the real command; show output and exit code |
| UI | walk the flow in the running app; screenshot, or a Bombadil smoke run |
| API | call the endpoint; show status and body |
| Parser or transform | replay saved real inputs; diff the output |
| Storage or migration | write then read back; run the migration on a copy of real data |
| Performance | before and after numbers with run count and spread |
| Config or infra | apply it and observe the effect |
| Bug fix | the failing repro now passes, and it failed before the fix |

Unit tests show branch behavior, not that the bug is gone. "It compiles" is not proof.

## 3. Check the diff

- No new comments outside the keep list. Hand the diff to a fresh agent running the `comment-review` skill; don't review your own comments.
- No skipped tests, loosened assertions, correctness-rule suppressions, casts that silence the type checker, debug logs or dead code.
- No unrelated changes. The diff is the smallest one that solves the problem.

## 4. Report

State what you ran and what you saw, with the evidence inline. Label each claim as measured, inferred or a guess. If any check could not run, say "not verified" and why. Inconclusive is never a pass.

Then hand the change to a different agent or a human for review. The author never approves its own work.
