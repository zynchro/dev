#!/usr/bin/env bash
set -euo pipefail

SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
REPO="$SANDBOX/zynchro dev"
mkdir -p "$REPO"
(cd "$SOURCE" && tar --exclude .git --exclude .omc --exclude nanny-hunt -cf - .) | (cd "$REPO" && tar -xf -)
mkdir -p "$SANDBOX/bin"
cp "$SOURCE/tests/fake-hermes" "$SANDBOX/bin/hermes"
export PATH="$SANDBOX/bin:$PATH"
unset CODEX_HOME ZYNCHRO_POOLS XDG_CONFIG_HOME FAKE_HERMES_FAIL_GET

passed=0
fail() { echo "FAIL: $*" >&2; echo "--- last output:" >&2; cat "$SANDBOX/out.log" >&2 2>/dev/null || true; exit 1; }
pass() { passed=$((passed + 1)); echo "ok - $*"; }
install() { "$REPO/install.sh" "$@" >"$SANDBOX/out.log" 2>&1; }
linked() { [ "$(readlink "$1")" = "$2" ] || fail "$1 should link to $2 (got: $(readlink "$1" 2>/dev/null || echo none))"; }
hook_cmd="\"$REPO/hooks/claude/stop-verify.sh\""
stop_hooks() { jq --arg c "$hook_cmd" '[.hooks.Stop[]?.hooks[]? | select(.command == $c)] | length' "$HOME/.claude/settings.json"; }
marker=$(sed -n "s/^MARKER='\(.*\)'$/\1/p" "$REPO/install.sh")

fresh_home() {
  export HOME="$SANDBOX/home-$1"
  export HERMES_HOME="$HOME/.hermes"
  mkdir -p "$HOME/.claude" "$HOME/.omp/agent" "$HERMES_HOME"
  cat >"$HOME/.claude/settings.json" <<'JSON'
{"outputStyle":"Concise","hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"echo existing"}]}]}}
JSON
}

fresh_home main
echo "my own omp rules" >"$HOME/.omp/agent/RULES.md"

install --dry-run || fail "dry-run exited non-zero"
[ ! -e "$HOME/.agents" ] || fail "dry-run created ~/.agents"
[ "$(cat "$HOME/.omp/agent/RULES.md")" = "my own omp rules" ] || fail "dry-run touched an existing file"
[ "$(stop_hooks)" = 0 ] || fail "dry-run added the Stop hook"
[ ! -e "$HOME/.zynchro-backups" ] || fail "dry-run wrote backups"
pass "dry-run changes nothing"

if install --check; then fail "check passed before install"; fi
pass "check reports drift before install"

install || fail "install failed"
for s in test-strategy bombadil quality-gate comment-review; do
  linked "$HOME/.agents/skills/$s" "$REPO/skills/$s"
  linked "$HOME/.claude/skills/$s" "$REPO/skills/$s"
done
linked "$HOME/.claude/rules/zynchro-rules.md" "$REPO/rules/RULES.md"
linked "$HOME/.claude/rules/zynchro-guide.md" "$REPO/rules/GUIDE.md"
linked "$HOME/.omp/agent/RULES.md" "$REPO/rules/RULES.md"
linked "$HOME/.omp/agent/AGENTS.md" "$REPO/rules/GUIDE.md"
pass "skills and rules are linked into a repo path with a space"

backup=$(find "$HOME/.zynchro-backups" -path '*/.omp/agent/RULES.md' -type f)
[ -n "$backup" ] && [ "$(cat "$backup")" = "my own omp rules" ] || fail "existing omp RULES.md was not moved to ~/.zynchro-backups intact"
[ -z "$(find "$HOME/.claude/skills" "$HOME/.agents/skills" -name '*.bak*' 2>/dev/null)" ] || fail "a backup landed inside a skills folder"
pass "replaced files are moved to ~/.zynchro-backups, never into skill folders"

[ "$(head -n 1 "$HOME/.codex/AGENTS.md")" = "$marker" ] || fail "Codex AGENTS.md lacks the marker"
grep -qF "$(head -n 1 "$REPO/rules/GUIDE.md")" "$HOME/.codex/AGENTS.md" || fail "Codex AGENTS.md lacks the guide"
pass "Codex AGENTS.md is generated from rules/"

[ "$(stop_hooks)" = 1 ] || fail "expected one quoted Stop hook, got $(stop_hooks)"
[ "$(jq -r '.outputStyle' "$HOME/.claude/settings.json")" = Concise ] || fail "settings.json lost outputStyle"
[ "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOME/.claude/settings.json")" = "echo existing" ] || fail "settings.json lost an existing hook"
[ -n "$(find "$HOME/.zynchro-backups" -name settings.json)" ] || fail "settings.json was not backed up before the rewrite"
pass "Stop hook added quoted, existing settings kept and backed up"

for p in default personal zynch; do
  ci="$HERMES_HOME/fake/$p/agent.coding_instructions"
  [ "$(head -n 1 "$ci")" = "$marker" ] || fail "Hermes[$p] coding_instructions lack the marker"
  grep -qF "$(head -n 1 "$REPO/rules/GUIDE.md")" "$ci" || fail "Hermes[$p] coding_instructions lack the guide"
  jq -e 'index($ENV.HOME + "/.agents/skills") != null' "$HERMES_HOME/fake/$p/skills.external_dirs" >/dev/null || fail "Hermes[$p] external_dirs not set"
done
[ ! -d "$HERMES_HOME/profiles/noon" ] || fail "noon pool must not be created by default"
[ "$(cat "$HOME/.config/zynchro/pools")" = "personal,zynch" ] || fail "pool choice not remembered"
pass "Hermes default and personal/zynch pools configured with rules and guide; no noon"

install || fail "second install failed"
[ "$(stop_hooks)" = 1 ] || fail "second install duplicated the Stop hook"
if grep -q '^  [+↺]' "$SANDBOX/out.log"; then fail "second install changed things"; fi
pass "install is idempotent"

install --check || fail "check failed after install"
pass "check passes after install"

rm "$HOME/.agents/skills/bombadil"
if install --check; then fail "check missed a removed skill link"; fi
grep -q "skills/bombadil is not linked" "$SANDBOX/out.log" || fail "check output does not name the drift"
install || fail "repair install failed"
pass "check detects drift and install repairs it"

if install --pools nope; then fail "unknown pool accepted"; fi
pass "unknown pool is rejected"
install --pools personal,zynch || fail "restoring the pool choice failed"

install --uninstall || fail "uninstall failed"
[ ! -e "$HOME/.agents/skills/bombadil" ] || fail "uninstall left a skill link"
[ ! -e "$HOME/.claude/rules/zynchro-rules.md" ] || fail "uninstall left Claude rules"
[ ! -e "$HOME/.codex/AGENTS.md" ] || fail "uninstall left Codex AGENTS.md"
[ "$(stop_hooks)" = 0 ] || fail "uninstall left the Stop hook"
[ "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOME/.claude/settings.json")" = "echo existing" ] || fail "uninstall removed someone else's hook"
[ "$(cat "$HOME/.omp/agent/RULES.md")" = "my own omp rules" ] || fail "uninstall did not restore the original omp RULES.md"
[ -d "$HERMES_HOME/profiles/personal" ] || fail "uninstall deleted a memory pool"
[ ! -e "$HERMES_HOME/fake/zynch/agent.coding_instructions" ] || fail "uninstall left pool coding_instructions"
[ ! -e "$HERMES_HOME/fake/default/agent.coding_instructions" ] || fail "uninstall left Hermes coding_instructions"
pass "uninstall removes what it made, restores what it moved, keeps pools and foreign hooks"

fresh_home work
install --pools noon || fail "work-laptop install failed"
install || fail "work-laptop rerun failed"
[ -d "$HERMES_HOME/profiles/noon" ] || fail "noon pool missing"
[ ! -d "$HERMES_HOME/profiles/personal" ] || fail "a plain rerun created personal pools on the work laptop"
install --check || fail "plain check on the work laptop reported false drift"
pass "the work laptop keeps its noon-only pool choice across reruns and checks"

fresh_home foreign
mkdir -p "$HERMES_HOME/fake/default"
printf 'my own hermes instructions' >"$HERMES_HOME/fake/default/agent.coding_instructions"
if install --no-pools; then fail "install should report foreign coding_instructions"; fi
[ "$(cat "$HERMES_HOME/fake/default/agent.coding_instructions")" = "my own hermes instructions" ] || fail "foreign coding_instructions were overwritten"
grep -q "already has its own coding_instructions" "$SANDBOX/out.log" || fail "no message about foreign coding_instructions"
pass "existing Hermes coding_instructions are never overwritten"

fresh_home unreadable
export FAKE_HERMES_FAIL_GET=1
if install --no-pools; then fail "install should report an unreadable Hermes config"; fi
unset FAKE_HERMES_FAIL_GET
[ ! -e "$HERMES_HOME/fake/default/skills.external_dirs" ] || fail "external_dirs written despite a failed read"
pass "an unreadable Hermes config is left alone"

fresh_home badjson
echo '{ not json' >"$HOME/.claude/settings.json"
if install --no-pools; then fail "install should report invalid settings.json"; fi
[ "$(cat "$HOME/.claude/settings.json")" = "{ not json" ] || fail "invalid settings.json was modified"
[ -z "$(find "$HOME/.claude" -name '*.tmp')" ] || fail "a temp file was left behind"
[ -f "$HOME/.codex/AGENTS.md" ] || fail "later steps were skipped after invalid settings.json"
pass "invalid settings.json is reported and left alone; other agents still install"

fresh_home symlinked
mv "$HOME/.claude/settings.json" "$SANDBOX/dotfiles-settings.json"
ln -s "$SANDBOX/dotfiles-settings.json" "$HOME/.claude/settings.json"
install --no-pools || fail "install with symlinked settings.json failed"
[ -L "$HOME/.claude/settings.json" ] || fail "symlinked settings.json was replaced by a file"
[ "$(stop_hooks)" = 1 ] || fail "hook not added through the symlink"
pass "a symlinked settings.json stays a symlink"

echo "all $passed install checks passed"
