#!/usr/bin/env bats
# Tests for scripts/lib/narrator.sh
# Covers: run_narrator — NARRATE_CMD routing and output trimming.
# NOTE: config.sh is NOT sourced here to avoid readonly conflicts;
# NARRATE_CMD and NARRATE_MAX_CHARS are set as plain env vars instead.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
  export NOTIFY_TITLE="Lazy Reader"
  export NARRATE_CMD=""
  export NARRATE_MAX_CHARS=2400
  # shellcheck source=scripts/lib/notify.sh
  source "${SCRIPTS_DIR}/lib/notify.sh"
  # shellcheck source=scripts/lib/selection.sh
  source "${SCRIPTS_DIR}/lib/selection.sh"
  # shellcheck source=scripts/lib/narrator.sh
  source "${SCRIPTS_DIR}/lib/narrator.sh"
}

teardown() {
  teardown_tmpdir
}

@test "run_narrator: exits non-zero when NARRATE_CMD is empty" {
  NARRATE_CMD=""
  run run_narrator "hello"
  [ "$status" -ne 0 ]
}

@test "run_narrator: returns output of NARRATE_CMD" {
  NARRATE_CMD="echo 'narrated'"
  run run_narrator "some input"
  [ "$status" -eq 0 ]
  [ "$output" = "narrated" ]
}

@test "run_narrator: pipes input text to NARRATE_CMD" {
  NARRATE_CMD="cat"
  run run_narrator "piped input"
  [ "$status" -eq 0 ]
  [ "$output" = "piped input" ]
}

@test "run_narrator: trims output to NARRATE_MAX_CHARS" {
  NARRATE_CMD="printf 'abcdefghij'"
  NARRATE_MAX_CHARS=5
  run run_narrator "input"
  [ "$status" -eq 0 ]
  [ "$output" = "abcde" ]
}

@test "run_narrator: exits non-zero when NARRATE_CMD fails" {
  NARRATE_CMD="exit 1"
  run run_narrator "input"
  [ "$status" -ne 0 ]
}

@test "run_narrator: exits non-zero when NARRATE_CMD returns empty output" {
  NARRATE_CMD="printf ''"
  run run_narrator "input"
  [ "$status" -ne 0 ]
}

@test "run_narrator: exits non-zero when NARRATE_CMD returns only whitespace" {
  NARRATE_CMD="printf '   '"
  run run_narrator "input"
  [ "$status" -ne 0 ]
}
