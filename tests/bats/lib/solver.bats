#!/usr/bin/env bats
# Tests for scripts/lib/solver.sh
# Covers: run_problem_solver — PROBLEM_SOLVER_CMD routing and output trimming.
# NOTE: config.sh is NOT sourced here to avoid readonly conflicts;
# PROBLEM_SOLVER_CMD and PROBLEM_SOLVER_MAX_CHARS are set as plain env vars instead.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
  export NOTIFY_TITLE="Lazy Reader"
  export PROBLEM_SOLVER_CMD=""
  export PROBLEM_SOLVER_MAX_CHARS=2400
  source "${SCRIPTS_DIR}/lib/notify.sh"
  source "${SCRIPTS_DIR}/lib/selection.sh"
  source "${SCRIPTS_DIR}/lib/solver.sh"
}

teardown() {
  teardown_tmpdir
}

@test "run_problem_solver: exits non-zero when PROBLEM_SOLVER_CMD is empty" {
  PROBLEM_SOLVER_CMD=""
  run run_problem_solver "hello"
  [ "$status" -ne 0 ]
}

@test "run_problem_solver: returns output of PROBLEM_SOLVER_CMD" {
  PROBLEM_SOLVER_CMD="echo 'solved'"
  run run_problem_solver "some input"
  [ "$status" -eq 0 ]
  [ "$output" = "solved" ]
}

@test "run_problem_solver: pipes input text to PROBLEM_SOLVER_CMD" {
  PROBLEM_SOLVER_CMD="cat"
  run run_problem_solver "piped input"
  [ "$status" -eq 0 ]
  [ "$output" = "piped input" ]
}

@test "run_problem_solver: trims output to PROBLEM_SOLVER_MAX_CHARS" {
  PROBLEM_SOLVER_CMD="printf 'abcdefghij'"
  PROBLEM_SOLVER_MAX_CHARS=5
  run run_problem_solver "input"
  [ "$status" -eq 0 ]
  [ "$output" = "abcde" ]
}

@test "run_problem_solver: exits non-zero when PROBLEM_SOLVER_CMD fails" {
  PROBLEM_SOLVER_CMD="exit 1"
  run run_problem_solver "input"
  [ "$status" -ne 0 ]
}

@test "run_problem_solver: exits non-zero when PROBLEM_SOLVER_CMD returns empty output" {
  PROBLEM_SOLVER_CMD="printf ''"
  run run_problem_solver "input"
  [ "$status" -ne 0 ]
}

@test "run_problem_solver: exits non-zero when PROBLEM_SOLVER_CMD returns only whitespace" {
  PROBLEM_SOLVER_CMD="printf '   '"
  run run_problem_solver "input"
  [ "$status" -ne 0 ]
}
