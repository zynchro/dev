#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

passed=0
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { passed=$((passed + 1)); echo "ok - $*"; }
fresh() {
  rm -rf "$SANDBOX/p"
  mkdir -p "$SANDBOX/p/scripts"
  git -C "$SANDBOX/p" init -q
  cp "$REPO/templates/project/scripts/verify" "$SANDBOX/p/scripts/verify"
}
verify() {
  set +e
  (cd "$SANDBOX/p" && scripts/verify) >"$SANDBOX/out" 2>&1
  code=$?
  set -e
}

fresh
verify
[ "$code" = 1 ] || fail "a repo with no checks must fail, got $code"
grep -q "no checks found" "$SANDBOX/out" || fail "no-checks message missing"
pass "a repo with no checks fails loudly"

fresh
echo '{"scripts":{"typecheck":"echo typed","test":"echo tested"}}' >"$SANDBOX/p/package.json"
verify
[ "$code" = 0 ] || fail "passing scripts should pass, got $code: $(cat "$SANDBOX/out")"
grep -q "typed" "$SANDBOX/out" || fail "typecheck script did not run"
grep -q "tested" "$SANDBOX/out" || fail "test script did not run"
grep -q "2 checks" "$SANDBOX/out" || fail "should report 2 checks"
pass "runs only the package.json scripts that exist"

fresh
echo '{"scripts":{"lint":"echo bad-lint; exit 3","test":"echo should-not-run"}}' >"$SANDBOX/p/package.json"
verify
[ "$code" != 0 ] || fail "a failing script must fail verify"
grep -q "should-not-run" "$SANDBOX/out" && fail "verify kept going after a failure"
pass "stops at the first failing check"

echo "all $passed verify-template checks passed"
