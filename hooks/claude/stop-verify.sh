#!/usr/bin/env bash
set -uo pipefail

VERIFY_DEADLINE=${ZYNCHRO_VERIFY_DEADLINE:-270}
OMC=':(exclude,glob)**/.omc/**'

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
again=$(jq -r '.stop_hook_active // false' <<<"$input")
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ "$(git -C "$root" config --bool zynchro.verify 2>/dev/null)" = true ] || exit 0
[ -x "$root/scripts/verify" ] || exit 0
[ -n "$(git -C "$root" status --porcelain -- . "$OMC" 2>/dev/null)" ] || exit 0

index=$(mktemp)
log=$(mktemp)
trap 'rm -f "$index" "$log"' EXIT
live_index=$(cd "$root" && git rev-parse --git-path index)
case "$live_index" in /*) ;; *) live_index="$root/$live_index" ;; esac
if [ -f "$live_index" ]; then
  cp "$live_index" "$index"
else
  rm -f "$index"
  GIT_INDEX_FILE=$index git -C "$root" read-tree --empty
fi
GIT_INDEX_FILE=$index git -C "$root" add -A -- . "$OMC" 2>/dev/null
key=$(GIT_INDEX_FILE=$index git -C "$root" write-tree)
cache="$(git -C "$root" rev-parse --absolute-git-dir)/zynchro-verify"
mkdir -p "$cache"

warn_user() { jq -n --arg m "$1" '{systemMessage: $m}'; }
unverified="scripts/verify fails in $root for the current code, so the agent's last answer is unverified."

[ -f "$cache/$key.pass" ] && exit 0
if [ -f "$cache/$key.fail" ]; then
  warn_user "$unverified"
  exit 0
fi

(cd "$root" && CI=1 perl -e 'alarm shift; exec @ARGV' "$VERIFY_DEADLINE" "${SHELL:-/bin/zsh}" -lic 'scripts/verify' </dev/null) >"$log" 2>&1
status=$?
if [ "$status" -eq 0 ]; then
  touch "$cache/$key.pass"
  exit 0
fi
[ "$status" -eq 142 ] && echo "scripts/verify did not finish within ${VERIFY_DEADLINE}s" >>"$log"
touch "$cache/$key.fail"

if [ "$again" = "true" ]; then
  warn_user "$unverified"
  exit 0
fi

{
  echo "scripts/verify failed in $root."
  echo "If your changes caused it, fix the cause without weakening any check, then finish."
  echo "If it was already failing before your changes, say so in your reply instead of fixing unrelated code."
  echo "Last output:"
  tail -n 60 "$log"
} >&2
exit 2
