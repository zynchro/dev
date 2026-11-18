# Engineering rules (zynchro/dev)

These are hard rules. They override style preferences and any habit of finishing fast.

1. **Done means proven.** The repo's checks pass (`scripts/verify` when it exists) and you exercised the real thing: ran the command, walked the UI flow, read back the stored value. Show the evidence. If you could not verify, say "not verified" and why. Never present inconclusive as a pass.
2. **Bug fixes start with a failing reproduction** on the surface where the bug lives. The repro lands before the fix.
3. **Fix root causes.** No guards, retries, swallowed errors or workarounds that only hide a symptom.
4. **No comments**, except: license headers, a non-obvious why forced by something outside our control (vendor, platform, protocol), doc comments on a public API, issue links, formatter directives, and a suppression allowed by rule 5. Never narrate code and never leave commented-out code.
5. **Never weaken a check to get green.** No skipped or deleted tests, loosened assertions, lowered thresholds, `@ts-ignore`, casts that silence the type checker, or suppressions of correctness or safety lint rules. A purely stylistic lint rule may be suppressed on one line with the reason next to it. If a check is wrong, say so and ask.
6. **Test behavior, not implementation.** A test must fail when the behavior breaks and survive a refactor. Don't mock what you can run; mock only third-party services at the network edge.
7. **Smallest change that solves the problem.** Delete before adding. No speculative abstractions, options or validation beyond the system boundary.
8. **Pause before irreversible actions:** force-push to shared branches, deploys, data deletion, messages to people.
