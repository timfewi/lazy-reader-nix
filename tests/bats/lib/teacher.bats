#!/usr/bin/env bats
# Tests for scripts/lib/teacher.sh
# Covers: run_teacher — TEACH_CMD routing and output trimming.
# NOTE: config.sh is NOT sourced here to avoid readonly conflicts;
# TEACH_CMD and TEACH_MAX_CHARS are set as plain env vars instead.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
  export NOTIFY_TITLE="Lazy Reader"
  export TEACH_CMD=""
  export TEACH_MAX_CHARS=3000
  # shellcheck source=scripts/lib/notify.sh
  source "${SCRIPTS_DIR}/lib/notify.sh"
  # shellcheck source=scripts/lib/selection.sh  (provides trim_text)
  source "${SCRIPTS_DIR}/lib/selection.sh"
  # shellcheck source=scripts/lib/teacher.sh
  source "${SCRIPTS_DIR}/lib/teacher.sh"
}

teardown() {
  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Missing / unconfigured command
# ---------------------------------------------------------------------------

@test "run_teacher: exits non-zero when TEACH_CMD is empty" {
  TEACH_CMD=""
  run run_teacher "some book text"
  [ "$status" -ne 0 ]
}

@test "run_teacher: notifies when TEACH_CMD is empty" {
  TEACH_CMD=""
  run run_teacher "some book text"
  [[ "$output" == *"No teach command configured"* ]]
}

# ---------------------------------------------------------------------------
# Successful execution
# ---------------------------------------------------------------------------

@test "run_teacher: returns output of TEACH_CMD" {
  TEACH_CMD="echo 'Here is the simple explanation'"
  run run_teacher "some book text"
  [ "$status" -eq 0 ]
  [ "$output" = "Here is the simple explanation" ]
}

@test "run_teacher: pipes input text to TEACH_CMD" {
  TEACH_CMD="cat"
  run run_teacher "this is a programming concept"
  [ "$status" -eq 0 ]
  [ "$output" = "this is a programming concept" ]
}

# ---------------------------------------------------------------------------
# Output trimming
# ---------------------------------------------------------------------------

@test "run_teacher: trims output to TEACH_MAX_CHARS" {
  TEACH_CMD="printf 'a%.0s' {1..200}"
  TEACH_MAX_CHARS=50
  run run_teacher "input"
  [ "$status" -eq 0 ]
  [ "${#output}" -le 53 ]
}

# ---------------------------------------------------------------------------
# Empty output
# ---------------------------------------------------------------------------

@test "run_teacher: exits non-zero when TEACH_CMD returns empty output" {
  TEACH_CMD="true"
  run run_teacher "some book text"
  [ "$status" -ne 0 ]
}

@test "run_teacher: notifies when TEACH_CMD returns empty output" {
  TEACH_CMD="true"
  run run_teacher "some book text"
  [[ "$output" == *"empty output"* ]]
}

# ---------------------------------------------------------------------------
# Failed command
# ---------------------------------------------------------------------------

@test "run_teacher: exits non-zero when TEACH_CMD fails" {
  TEACH_CMD="exit 1"
  run run_teacher "some book text"
  [ "$status" -ne 0 ]
}

@test "run_teacher: notifies when TEACH_CMD fails" {
  TEACH_CMD="exit 1"
  run run_teacher "some book text"
  [[ "$output" == *"Teach command failed"* ]]
}
