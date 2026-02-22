#!/usr/bin/env bats
# Tests for scripts/lib/selection.sh
# Covers: trim_text (pure), read_selection (stubbed wl-paste)

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  # shellcheck source=scripts/lib/selection.sh
  source "${SCRIPTS_DIR}/lib/selection.sh"
}

teardown() {
  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# trim_text — invariants
# ---------------------------------------------------------------------------

@test "trim_text: returns text unchanged when shorter than limit" {
  [ "$(trim_text 'hello' 10)" = "hello" ]
}

@test "trim_text: returns text unchanged when equal to limit" {
  [ "$(trim_text 'hello' 5)" = "hello" ]
}

@test "trim_text: truncates to exactly max_chars" {
  [ "$(trim_text 'hello world' 5)" = "hello" ]
}

@test "trim_text: truncates to a single character" {
  [ "$(trim_text 'abc' 1)" = "a" ]
}

@test "trim_text: handles empty input" {
  [ "$(trim_text '' 10)" = "" ]
}

@test "trim_text: invariant — output length never exceeds max_chars" {
  local input="abcdefghijklmnopqrstuvwxyz"
  for max in 0 1 5 10 26 100; do
    local result
    result="$(trim_text "$input" "$max")"
    (( ${#result} <= max ))
  done
}

# ---------------------------------------------------------------------------
# read_selection — stubbed wl-paste
# ---------------------------------------------------------------------------

@test "read_selection: returns primary selection when non-empty" {
  make_stub "wl-paste" 'printf "selected text"'
  [ "$(read_selection)" = "selected text" ]
}

@test "read_selection: falls back to clipboard when primary is empty" {
  make_stub "wl-paste" '
    for arg in "$@"; do
      [[ "$arg" == "--primary" ]] && { printf ""; exit 0; }
    done
    printf "clipboard text"'
  [ "$(read_selection)" = "clipboard text" ]
}

@test "read_selection: returns empty string when wl-paste returns nothing" {
  make_stub "wl-paste" 'printf ""'
  [ "$(read_selection)" = "" ]
}
