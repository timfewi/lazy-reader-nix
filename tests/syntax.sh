#!/usr/bin/env bash
# Validate shell script and Nix file syntax.
# Exits non-zero if any check fails.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok  %s\n' "$desc"
    (( PASS++ )) || true
  else
    printf '  FAIL %s\n' "$desc" >&2
    (( FAIL++ )) || true
  fi
}

echo "Bash syntax:"
for f in \
    "${REPO_ROOT}/scripts/"*.sh \
    "${REPO_ROOT}/scripts/lib/"*.sh; do
  check "${f#"${REPO_ROOT}/"}" bash -n "$f"
done

echo ""
echo "Nix syntax:"
for f in \
    "${REPO_ROOT}/lazy-reader.nix" \
    "${REPO_ROOT}/default.nix" \
    "${REPO_ROOT}/nix/"*.nix; do
  check "${f#"${REPO_ROOT}/"}" nix-instantiate --parse "$f"
done

echo ""
printf 'Syntax: %d passed, %d failed.\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
