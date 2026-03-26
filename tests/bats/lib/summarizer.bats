#!/usr/bin/env bats
# Tests for scripts/lib/summarizer.sh
# Covers: run_summarizer — SUMMARIZE_CMD routing and output trimming.
# NOTE: config.sh is NOT sourced here to avoid readonly conflicts;
# SUMMARIZE_CMD and SUMMARIZE_MAX_CHARS are set as plain env vars instead.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
  export NOTIFY_TITLE="Lazy Reader"
  export SUMMARIZE_CMD=""
  export SUMMARIZE_MAX_CHARS=3200
  # shellcheck source=scripts/lib/notify.sh
  source "${SCRIPTS_DIR}/lib/notify.sh"
  # shellcheck source=scripts/lib/selection.sh  (provides trim_text)
  source "${SCRIPTS_DIR}/lib/selection.sh"
  # shellcheck source=scripts/lib/summarizer.sh
  source "${SCRIPTS_DIR}/lib/summarizer.sh"
}

teardown() {
  teardown_tmpdir
}

@test "run_summarizer: exits non-zero when SUMMARIZE_CMD is empty" {
  SUMMARIZE_CMD=""
  run run_summarizer "hello"
  [ "$status" -ne 0 ]
}

@test "run_summarizer: returns output of SUMMARIZE_CMD" {
  SUMMARIZE_CMD="echo 'summarized'"
  run run_summarizer "some input"
  [ "$status" -eq 0 ]
  [ "$output" = "summarized" ]
}

@test "run_summarizer: pipes input text to SUMMARIZE_CMD" {
  SUMMARIZE_CMD="cat"
  run run_summarizer "piped input"
  [ "$status" -eq 0 ]
  [ "$output" = "piped input" ]
}

@test "run_summarizer: trims output to SUMMARIZE_MAX_CHARS" {
  SUMMARIZE_CMD="printf 'abcdefghij'"
  SUMMARIZE_MAX_CHARS=5
  run run_summarizer "input"
  [ "$status" -eq 0 ]
  [ "$output" = "abcde" ]
}

@test "run_summarizer: exits non-zero when SUMMARIZE_CMD fails" {
  SUMMARIZE_CMD="exit 1"
  run run_summarizer "input"
  [ "$status" -ne 0 ]
}

@test "run_summarizer: exits non-zero when SUMMARIZE_CMD returns empty output" {
  SUMMARIZE_CMD="printf ''"
  run run_summarizer "input"
  [ "$status" -ne 0 ]
}

@test "run_summarizer: exits non-zero when SUMMARIZE_CMD returns only whitespace" {
  SUMMARIZE_CMD="printf '   '"
  run run_summarizer "input"
  [ "$status" -ne 0 ]
}
