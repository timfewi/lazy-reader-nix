#!/usr/bin/env bats
# Tests for scripts/lib/pid.sh
# Covers: is_running, cleanup_stale_pid_file

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

# PID of a helper background process spawned within a test (killed in teardown).
HELPER_PID=""

setup() {
  setup_tmpdir
  make_stub "notify-send"
  export NOTIFY_TITLE="Lazy Reader"
  export PID_FILE="${XDG_RUNTIME_DIR}/lazy-reader.pid"
  # shellcheck source=scripts/lib/notify.sh
  source "${SCRIPTS_DIR}/lib/notify.sh"
  # shellcheck source=scripts/lib/pid.sh
  source "${SCRIPTS_DIR}/lib/pid.sh"
}

teardown() {
  [[ -n "${HELPER_PID:-}" ]] && kill "${HELPER_PID}" 2>/dev/null || true
  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# is_running
# ---------------------------------------------------------------------------

@test "is_running: returns false when PID file does not exist" {
  run is_running
  [ "$status" -ne 0 ]
}

@test "is_running: returns true when PID file contains a running PID" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "$PID_FILE"
  run is_running
  [ "$status" -eq 0 ]
}

@test "is_running: returns false when PID file contains non-numeric content" {
  echo "not-a-pid" > "$PID_FILE"
  run is_running
  [ "$status" -ne 0 ]
}

@test "is_running: returns false when PID file contains a dead PID" {
  sleep 100 &
  local dead_pid=$!
  kill "$dead_pid"
  wait "$dead_pid" 2>/dev/null || true
  echo "$dead_pid" > "$PID_FILE"
  run is_running
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# cleanup_stale_pid_file
# ---------------------------------------------------------------------------

@test "cleanup_stale_pid_file: removes stale PID file" {
  sleep 100 &
  local dead_pid=$!
  kill "$dead_pid"
  wait "$dead_pid" 2>/dev/null || true
  echo "$dead_pid" > "$PID_FILE"
  cleanup_stale_pid_file
  [ ! -f "$PID_FILE" ]
}

@test "cleanup_stale_pid_file: leaves valid PID file intact" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "$PID_FILE"
  cleanup_stale_pid_file
  [ -f "$PID_FILE" ]
}

@test "cleanup_stale_pid_file: does nothing when no PID file exists" {
  cleanup_stale_pid_file
  [ ! -f "$PID_FILE" ]
}

# ---------------------------------------------------------------------------
# cleanup
# ---------------------------------------------------------------------------

@test "cleanup: removes MODEL_DIR when set" {
  local dir
  dir="$(mktemp -d)"
  MODEL_DIR="$dir"
  PLAYER_PID=""
  RESPONSE_FILE=""
  OWNS_PID_FILE="0"
  cleanup
  [ ! -d "$dir" ]
}

@test "cleanup: succeeds when MODEL_DIR is empty" {
  MODEL_DIR=""
  PLAYER_PID=""
  RESPONSE_FILE=""
  OWNS_PID_FILE="0"
  run cleanup
  [ "$status" -eq 0 ]
}
