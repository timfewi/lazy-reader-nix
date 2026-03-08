#!/usr/bin/env bats
# Tests for scripts/lib/asker.sh
# Covers: run_asker — ASK_CMD routing, question prompt, env-var contract, output trimming.
# NOTE: config.sh is NOT sourced here to avoid readonly conflicts;
# ASK_CMD and ASK_MAX_CHARS are set as plain env vars instead.
# zenity is stubbed via PATH so no display is required.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
  # Default zenity stub: user types "my question" and presses OK.
  make_stub "zenity" 'printf "my question"'
  export NOTIFY_TITLE="Lazy Reader"
  export ASK_CMD=""
  export ASK_MAX_CHARS=2400
  # shellcheck source=scripts/lib/notify.sh
  source "${SCRIPTS_DIR}/lib/notify.sh"
  # shellcheck source=scripts/lib/selection.sh
  source "${SCRIPTS_DIR}/lib/selection.sh"
  # shellcheck source=scripts/lib/asker.sh
  source "${SCRIPTS_DIR}/lib/asker.sh"
}

teardown() {
  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Missing / unconfigured command
# ---------------------------------------------------------------------------

@test "run_asker: exits non-zero when ASK_CMD is empty" {
  ASK_CMD=""
  run run_asker "hello"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Successful execution
# ---------------------------------------------------------------------------

@test "run_asker: prompts via zenity and returns ASK_CMD output" {
  ASK_CMD="echo 'answered'"
  run run_asker "some input"
  [ "$status" -eq 0 ]
  [ "$output" = "answered" ]
}

@test "run_asker: pipes selected text to ASK_CMD on stdin" {
  ASK_CMD="cat"
  run run_asker "piped input"
  [ "$status" -eq 0 ]
  [ "$output" = "piped input" ]
}

@test "run_asker: passes typed question as LAZY_READER_ASK_QUESTION env var" {
  # zenity stub prints "my question"; ASK_CMD echoes the env var.
  ASK_CMD='printf "%s" "$LAZY_READER_ASK_QUESTION"'
  run run_asker "some text"
  [ "$status" -eq 0 ]
  [ "$output" = "my question" ]
}

@test "run_asker: trims output to ASK_MAX_CHARS" {
  ASK_CMD="printf 'abcdefghij'"
  ASK_MAX_CHARS=5
  run run_asker "input"
  [ "$status" -eq 0 ]
  [ "$output" = "abcde" ]
}

# ---------------------------------------------------------------------------
# Cancelled dialog / empty question
# ---------------------------------------------------------------------------

@test "run_asker: returns 2 when zenity is cancelled" {
  # Stub zenity to simulate cancel (exit 1).
  make_stub "zenity" 'exit 1'
  ASK_CMD="echo 'should not run'"
  run run_asker "some text"
  [ "$status" -eq 2 ]
}

@test "run_asker: returns 2 when zenity returns empty question" {
  # Stub zenity to return blank input.
  make_stub "zenity" 'printf ""'
  ASK_CMD="echo 'should not run'"
  run run_asker "some text"
  [ "$status" -eq 2 ]
}

@test "run_asker: returns 2 when zenity returns whitespace-only question" {
  make_stub "zenity" 'printf "   "'
  ASK_CMD="echo 'should not run'"
  run run_asker "some text"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Failure modes
# ---------------------------------------------------------------------------

@test "run_asker: exits non-zero when ASK_CMD fails" {
  ASK_CMD="exit 1"
  run run_asker "input"
  [ "$status" -ne 0 ]
}

@test "run_asker: exits non-zero when ASK_CMD returns empty output" {
  ASK_CMD="printf ''"
  run run_asker "input"
  [ "$status" -ne 0 ]
}

@test "run_asker: exits non-zero when ASK_CMD returns only whitespace" {
  ASK_CMD="printf '   '"
  run run_asker "input"
  [ "$status" -ne 0 ]
}
