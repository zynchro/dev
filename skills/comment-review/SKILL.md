---
name: comment-review
description: Review a diff or files for code comments and remove every comment that is not on the keep list, fixing the code that needed it. Use before review or commit, when asked to remove comments or slop, or when code is full of narration or workaround notes.
---

# Comment review

Run this as a fresh reviewer, not as the author of the code. Authors defend their comments.

## Keep list (the only comments that survive)

1. License or legal headers.
2. A non-obvious why forced by something we can't change: a vendor quirk, platform bug, protocol rule or external API behavior.
3. Doc comments that define a public API contract.
4. Issue or RFC links that explain a constraint the code can't express.
5. Formatter directives such as `// prettier-ignore`.
6. A suppression of a purely stylistic lint rule, on one line, with the reason next to it. Suppressions of correctness or safety rules never survive; fix the code instead.

When unsure whether a comment fits the list, it goes.

## Procedure

1. List every comment added or touched in the diff (or in the named files).
2. Delete anything not on the keep list: narration, section banners, commented-out code, TODOs without an issue link, "important", "do not remove", "fine for now" and long justifications.
3. Where a comment was propping up unclear code, fix the code instead: rename, extract a function, add a type, or make the state explicit.
4. Where a comment protected a constraint ("must run before X", "never null here"), encode it as a type, an assertion, a test or a lint rule, then delete the comment.
5. Where a comment justified a workaround for our own bug, flag it: the root cause needs fixing, not explaining.
6. Run the repo's checks after editing.

## Report

List what you removed, what you encoded as a check, and every workaround you flagged for a root-cause fix.
