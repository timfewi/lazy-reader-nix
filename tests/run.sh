#!/usr/bin/env bash
# Run the full test suite: syntax checks + bats unit tests.
# Usage: bash tests/run.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Syntax checks"
bash "${REPO_ROOT}/tests/syntax.sh"

echo ""
echo "==> Bats unit tests"
if command -v bats >/dev/null 2>&1; then
  exec bats --recursive "${REPO_ROOT}/tests/bats"
else
  exec nix-shell -p bats --run "bats --recursive '${REPO_ROOT}/tests/bats'"
fi
