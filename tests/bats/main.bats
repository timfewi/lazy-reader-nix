#!/usr/bin/env bats
# Integration tests for scripts/lazy-reader.sh — main() dispatch logic.
# External tools (piper, mpv, wl-paste, notify-send) are stubbed via PATH.
# Tests cover: status, stop, start, explain, summarize, solve, ask, unknown-command routing.

load 'helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../scripts"
LAZY_READER="${SCRIPTS_DIR}/../scripts/lazy-reader.sh"

# PID of a helper background process; cleaned up in teardown.
HELPER_PID=""

setup() {
  setup_tmpdir
  MODEL_FILE="$(make_model_file)"
  export MODEL_FILE
  make_stub "notify-send"
  make_stub "piper"
  make_stub "mpv"
  make_stub "wl-paste" 'printf "some text"'
}

teardown() {
  [[ -n "${HELPER_PID:-}" ]] && kill "${HELPER_PID}" 2>/dev/null || true
  teardown_tmpdir
}

# Convenience wrapper — sets required env and runs the script.
# Usage: run_lr [args...]
run_lr() {
  run env \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    "PATH=${PATH}" \
    bash "${SCRIPTS_DIR}/lazy-reader.sh" "$@"
}

# ---------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------

@test "status: prints 'idle' when no PID file exists" {
  run_lr status
  [ "$status" -eq 0 ]
  [ "$output" = "idle" ]
}

@test "status: prints 'reading' when PID file has an active process" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr status
  [ "$status" -eq 0 ]
  [ "$output" = "reading" ]
}

@test "status: prints 'idle' after a stale PID file is present" {
  sleep 100 &
  local dead_pid=$!
  kill "$dead_pid"
  wait "$dead_pid" 2>/dev/null || true
  echo "$dead_pid" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr status
  [ "$status" -eq 0 ]
  [ "$output" = "idle" ]
}

# ---------------------------------------------------------------------------
# stop
# ---------------------------------------------------------------------------

@test "stop: exits 0 when nothing is running" {
  run_lr stop
  [ "$status" -eq 0 ]
}

@test "stop: removes stale PID file" {
  sleep 100 &
  local dead_pid=$!
  kill "$dead_pid"
  wait "$dead_pid" 2>/dev/null || true
  echo "$dead_pid" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr stop
  [ ! -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]
}

# ---------------------------------------------------------------------------
# start — already running
# ---------------------------------------------------------------------------

@test "start: exits 0 and does not start again when already running" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr start
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# explain — already running
# ---------------------------------------------------------------------------

@test "explain: exits 0 and stops reading when already running" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr explain
  [ "$status" -eq 0 ]
  [ ! -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]
  ! kill -0 "$HELPER_PID" 2>/dev/null
}

# ---------------------------------------------------------------------------
# summarize / solve / ask — already running
# ---------------------------------------------------------------------------

@test "summarize: exits 0 and stops reading when already running" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr summarize
  [ "$status" -eq 0 ]
  [ ! -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]
  ! kill -0 "$HELPER_PID" 2>/dev/null
}

@test "solve: exits 0 and stops reading when already running" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr solve
  [ "$status" -eq 0 ]
  [ ! -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]
  ! kill -0 "$HELPER_PID" 2>/dev/null
}

@test "ask: exits 0 and stops reading when already running" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr ask
  [ "$status" -eq 0 ]
  [ ! -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]
  ! kill -0 "$HELPER_PID" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Unknown command
# ---------------------------------------------------------------------------

@test "unknown command: exits non-zero" {
  run_lr notacommand
  [ "$status" -ne 0 ]
}
