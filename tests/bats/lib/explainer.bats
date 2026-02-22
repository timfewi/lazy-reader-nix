#!/usr/bin/env bats
# Tests for scripts/lib/explainer.sh
# Covers: run_explainer — EXPLAIN_CMD routing and output trimming.
# NOTE: config.sh is NOT sourced here to avoid readonly conflicts;
# EXPLAIN_CMD and EXPLAIN_MAX_CHARS are set as plain env vars instead.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
  export NOTIFY_TITLE="Lazy Reader"
  export EXPLAIN_CMD=""
  export EXPLAIN_MAX_CHARS=2400
  # shellcheck source=scripts/lib/notify.sh
  source "${SCRIPTS_DIR}/lib/notify.sh"
  # shellcheck source=scripts/lib/selection.sh  (provides trim_text)
  source "${SCRIPTS_DIR}/lib/selection.sh"
  # shellcheck source=scripts/lib/explainer.sh
  source "${SCRIPTS_DIR}/lib/explainer.sh"
}

teardown() {
  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Missing / unconfigured command
# ---------------------------------------------------------------------------

@test "run_explainer: exits non-zero when EXPLAIN_CMD is empty" {
  EXPLAIN_CMD=""
  run run_explainer "hello"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Successful execution
# ---------------------------------------------------------------------------

@test "run_explainer: returns output of EXPLAIN_CMD" {
  EXPLAIN_CMD="echo 'explained'"
  run run_explainer "some input"
  [ "$status" -eq 0 ]
  [ "$output" = "explained" ]
}

@test "run_explainer: pipes input text to EXPLAIN_CMD" {
  EXPLAIN_CMD="cat"
  run run_explainer "piped input"
  [ "$status" -eq 0 ]
  [ "$output" = "piped input" ]
}

@test "run_explainer: trims output to EXPLAIN_MAX_CHARS" {
  EXPLAIN_CMD="printf 'abcdefghij'"
  EXPLAIN_MAX_CHARS=5
  run run_explainer "input"
  [ "$status" -eq 0 ]
  [ "$output" = "abcde" ]
}

# ---------------------------------------------------------------------------
# Failure modes
# ---------------------------------------------------------------------------

@test "run_explainer: exits non-zero when EXPLAIN_CMD fails" {
  EXPLAIN_CMD="exit 1"
  run run_explainer "input"
  [ "$status" -ne 0 ]
}

@test "run_explainer: exits non-zero when EXPLAIN_CMD returns empty output" {
  EXPLAIN_CMD="printf ''"
  run run_explainer "input"
  [ "$status" -ne 0 ]
}

@test "run_explainer: exits non-zero when EXPLAIN_CMD returns only whitespace" {
  EXPLAIN_CMD="printf '   '"
  run run_explainer "input"
  [ "$status" -ne 0 ]
}
