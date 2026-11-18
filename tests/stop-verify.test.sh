#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$REPO/hooks/claude/stop-verify.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export SHELL=/bin/bash
P="$SANDBOX/repo"

passed=0
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { passed=$((passed + 1)); echo "ok - $*"; }
run_hook() {
  local active=$1 dir=${2:-$P}
  set +e
  jq -n --arg cwd "$dir" --argjson a "$active" '{cwd: $cwd, stop_hook_active: $a}' | "$HOOK" >"$SANDBOX/stdout" 2>"$SANDBOX/stderr"
  code=$?
  set -e
}
set_verify() {
  printf '#!/usr/bin/env bash\necho run >>"%s/runs"\necho "lint: 3 problems"\nexit %s\n' "$SANDBOX" "$1" >"$P/scripts/verify"
  chmod +x "$P/scripts/verify"
}
runs() { if [ -f "$SANDBOX/runs" ]; then wc -l <"$SANDBOX/runs" | tr -d ' '; else echo 0; fi; }

mkdir -p "$SANDBOX/plain"
run_hook false "$SANDBOX/plain"
[ "$code" = 0 ] || fail "a non-git directory should pass, got $code"
pass "non-git directories are ignored"

mkdir -p "$P/scripts"
git -C "$P" init -q
set_verify 1
git -C "$P" add -A
git -C "$P" -c user.email=t@t -c user.name=t commit -qm init
echo change >"$P/file.txt"
run_hook false
[ "$code" = 0 ] && [ "$(runs)" = 0 ] || fail "a repo that has not opted in must not run verify"
pass "repos run verify only after opting in with git config zynchro.verify true"

git -C "$P" config zynchro.verify true
rm "$P/file.txt"
mkdir -p "$P/.omc/state"
echo x >"$P/.omc/state/s.json"
run_hook false
[ "$code" = 0 ] && [ "$(runs)" = 0 ] || fail "changes only under .omc must not run verify"
pass "oh-my-claudecode state files don't count as changes"

echo change >"$P/file.txt"
run_hook false
[ "$code" = 2 ] || fail "failing verify should block once (exit 2), got $code"
grep -q "lint: 3 problems" "$SANDBOX/stderr" || fail "block message lacks verify output"
grep -q "already failing before your changes" "$SANDBOX/stderr" || fail "block message lacks the pre-existing-failure guidance"
pass "failing verify blocks the stop with its output and guidance"

run_hook true
[ "$code" = 0 ] || fail "second stop on the same code should not block, got $code"
[ "$(runs)" = 1 ] || fail "verify reran on unchanged code ($(runs) runs)"
jq -e '.systemMessage | test("unverified")' "$SANDBOX/stdout" >/dev/null || fail "user is not warned that the answer is unverified"
pass "same failing code is not rerun; the user is warned instead"

run_hook false
[ "$code" = 0 ] && [ "$(runs)" = 1 ] || fail "a later turn on the same failing code should warn, not rerun or block"
pass "later turns on unchanged failing code don't rerun verify"

set_verify 0
echo fixed >>"$P/file.txt"
run_hook true
[ "$code" = 0 ] || fail "passing verify should allow the stop, got $code"
[ "$(runs)" = 2 ] || fail "changed code should rerun verify"
run_hook false
[ "$(runs)" = 2 ] || fail "a passing state should be cached"
pass "passing verify allows the stop and is cached per code state"

mkdir -p "$P/pkg/.omc"
echo x >"$P/pkg/.omc/state.json"
git -C "$P" add -A
git -C "$P" -c user.email=t@t -c user.name=t commit -qm "pkg" -- . ':(exclude,glob)**/.omc/**'
git -C "$P" rm -rq --cached pkg/.omc 2>/dev/null || true
echo y >"$P/pkg/.omc/state.json"
before=$(runs)
run_hook false
[ "$code" = 0 ] && [ "$(runs)" = "$before" ] || fail "changes only in a nested .omc must not run verify"
pass "nested oh-my-claudecode state folders don't count as changes"

printf '#!/usr/bin/env bash\necho run >>"%s/runs"\nsleep 30\n' "$SANDBOX" >"$P/scripts/verify"
echo slow >>"$P/file.txt"
before=$(runs)
start=$(date +%s)
ZYNCHRO_VERIFY_DEADLINE=2 run_hook false
elapsed=$(( $(date +%s) - start ))
[ "$code" = 2 ] || fail "a verify past the deadline should block like a failure, got $code"
[ "$elapsed" -lt 15 ] || fail "deadline not enforced (${elapsed}s)"
grep -q "did not finish within 2s" "$SANDBOX/stderr" || fail "timeout reason missing from the block message"
ZYNCHRO_VERIFY_DEADLINE=2 run_hook true
[ "$(runs)" = $((before + 1)) ] || fail "a timed-out verify reran on unchanged code"
pass "a verify past the deadline is stopped, reported and cached as a failure"

echo "all $passed stop-hook checks passed"
