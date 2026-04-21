#!/usr/bin/env bats
# Integration tests for scripts/lazy-reader.sh — main() dispatch logic.
# External tools (piper, mpv, wl-paste, notify-send) are stubbed via PATH.
# Tests cover: status, stop, start, narrate, explain, summarize, solve, ask, unknown-command routing.

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

@test "start: reads long selections in sentence-aware chunks" {
  local chunk_log="${TEST_TMPDIR}/chunks.log"

  make_stub "wl-paste" 'printf "%s" "$LAZY_READER_TEST_SELECTION"'
  make_stub "piper" '
    output=""
    while (($#)); do
      if [[ "$1" == "-f" ]]; then
        output="$2"
        shift 2
        continue
      fi
      shift
    done
    input="$(cat)"
    printf "%s\n--chunk--\n" "$input" >> "$LAZY_READER_TEST_CHUNK_LOG"
    if [[ "$output" == "-" ]]; then
      printf "wave-data"
    else
      printf "wave-data" > "$output"
    fi
  '
  make_stub "mpv" 'cat >/dev/null'

  run env \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    "LAZY_READER_MAX_CHARS=25" \
    "LAZY_READER_TEST_SELECTION=First sentence. Second sentence. Third sentence." \
    "LAZY_READER_TEST_CHUNK_LOG=${chunk_log}" \
    "PATH=${PATH}" \
    bash "${SCRIPTS_DIR}/lazy-reader.sh" start

  [ "$status" -eq 0 ]
  run bash -c "grep -c '^--chunk--$' '${chunk_log}'"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]
  run bash -c "head -n 1 '${chunk_log}'"
  [ "$status" -eq 0 ]
  [ "$output" = "First sentence." ]
}

@test "start: prefers piped stdin over Wayland selection" {
  local speech_log="${TEST_TMPDIR}/stdin.log"

  make_stub "wl-paste" 'printf "selected text"'
  make_stub "piper" '
    output=""
    while (($#)); do
      if [[ "$1" == "-f" ]]; then
        output="$2"
        shift 2
        continue
      fi
      shift
    done
    input="$(cat)"
    printf "%s" "$input" > "$LAZY_READER_TEST_SPEECH_LOG"
    if [[ "$output" == "-" ]]; then
      printf "wave-data"
    else
      printf "wave-data" > "$output"
    fi
  '
  make_stub "mpv" 'cat >/dev/null'

  run bash -c "
    printf 'stdin text' |
      env \
        XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' \
        LAZY_READER_MODEL='${MODEL_FILE}' \
        LAZY_READER_TEST_SPEECH_LOG='${speech_log}' \
        PATH='${PATH}' \
        bash '${SCRIPTS_DIR}/lazy-reader.sh' start
  "

  [ "$status" -eq 0 ]

  run cat "${speech_log}"
  [ "$status" -eq 0 ]
  [ "$output" = "stdin text" ]
}

@test "start: provider hook wins over piped stdin" {
  local speech_log="${TEST_TMPDIR}/provider.log"

  make_stub "wl-paste" 'printf "selected text"'
  make_stub "piper" '
    output=""
    while (($#)); do
      if [[ "$1" == "-f" ]]; then
        output="$2"
        shift 2
        continue
      fi
      shift
    done
    input="$(cat)"
    printf "%s" "$input" > "$LAZY_READER_TEST_SPEECH_LOG"
    if [[ "$output" == "-" ]]; then
      printf "wave-data"
    else
      printf "wave-data" > "$output"
    fi
  '
  make_stub "mpv" 'cat >/dev/null'

  run bash -c "
    printf 'stdin text' |
      env \
        XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' \
        LAZY_READER_MODEL='${MODEL_FILE}' \
        LAZY_READER_INPUT_PROVIDER_CMD=\"printf '%s' 'provider text'\" \
        LAZY_READER_TEST_SPEECH_LOG='${speech_log}' \
        PATH='${PATH}' \
        bash '${SCRIPTS_DIR}/lazy-reader.sh' start
  "

  [ "$status" -eq 0 ]

  run cat "${speech_log}"
  [ "$status" -eq 0 ]
  [ "$output" = "provider text" ]
}

@test "stop: cancels an active chunked read" {
  local chunk_log="${TEST_TMPDIR}/chunks-stop.log"

  make_stub "wl-paste" 'printf "%s" "$LAZY_READER_TEST_SELECTION"'
  make_stub "piper" '
    output=""
    while (($#)); do
      if [[ "$1" == "-f" ]]; then
        output="$2"
        shift 2
        continue
      fi
      shift
    done
    input="$(cat)"
    printf "%s\n--chunk--\n" "$input" >> "$LAZY_READER_TEST_CHUNK_LOG"
    if [[ "$output" == "-" ]]; then
      printf "wave-data"
    else
      printf "wave-data" > "$output"
    fi
  '
  make_stub "mpv" 'sleep 60'

  env \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    "LAZY_READER_MAX_CHARS=25" \
    "LAZY_READER_TEST_SELECTION=First sentence. Second sentence. Third sentence." \
    "LAZY_READER_TEST_CHUNK_LOG=${chunk_log}" \
    "PATH=${PATH}" \
    bash "${SCRIPTS_DIR}/lazy-reader.sh" start &
  HELPER_PID=$!

  for _ in {1..40}; do
    [[ -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]] && break
    sleep 0.05
  done

  [ -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]

  run_lr stop
  [ "$status" -eq 0 ]

  wait "$HELPER_PID" 2>/dev/null || true
  ! kill -0 "$HELPER_PID" 2>/dev/null
  [ ! -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]
}

# ---------------------------------------------------------------------------
# narrate
# ---------------------------------------------------------------------------

@test "narrate: uses narrate input limit instead of plain reader max chars" {
  local speech_log="${TEST_TMPDIR}/narrate.log"

  make_stub "wl-paste" 'printf "%s" "$LAZY_READER_TEST_SELECTION"'
  make_stub "piper" '
    output=""
    while (($#)); do
      if [[ "$1" == "-f" ]]; then
        output="$2"
        shift 2
        continue
      fi
      shift
    done
    input="$(cat)"
    printf "%s" "$input" > "$LAZY_READER_TEST_SPEECH_LOG"
    if [[ "$output" == "-" ]]; then
      printf "wave-data"
    else
      printf "wave-data" > "$output"
    fi
  '
  make_stub "mpv" 'cat >/dev/null'

  run env \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    "LAZY_READER_MAX_CHARS=5" \
    "LAZY_READER_NARRATE_INPUT_MAX_CHARS=8" \
    "LAZY_READER_NARRATE_MAX_CHARS=30" \
    "LAZY_READER_NARRATE_CMD=input=\"\$(cat)\"; printf \"Narrated: %s\" \"\$input\"" \
    "LAZY_READER_TEST_SELECTION=abcdefghij" \
    "LAZY_READER_TEST_SPEECH_LOG=${speech_log}" \
    "PATH=${PATH}" \
    bash "${SCRIPTS_DIR}/lazy-reader.sh" narrate

  [ "$status" -eq 0 ]

  run cat "${speech_log}"
  [ "$status" -eq 0 ]
  [ "$output" = "Narrated: abcdefgh" ]
}

@test "explain: accepts direct --text input" {
  local speech_log="${TEST_TMPDIR}/explain-arg.log"

  make_stub "piper" '
    output=""
    while (($#)); do
      if [[ "$1" == "-f" ]]; then
        output="$2"
        shift 2
        continue
      fi
      shift
    done
    input="$(cat)"
    printf "%s" "$input" > "$LAZY_READER_TEST_SPEECH_LOG"
    if [[ "$output" == "-" ]]; then
      printf "wave-data"
    else
      printf "wave-data" > "$output"
    fi
  '
  make_stub "mpv" 'cat >/dev/null'

  run env \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    "LAZY_READER_EXPLAIN_CMD=printf 'Explained: %s' \"\$(cat)\"" \
    "LAZY_READER_TEST_SPEECH_LOG=${speech_log}" \
    "PATH=${PATH}" \
    bash "${SCRIPTS_DIR}/lazy-reader.sh" explain --text "argument text"

  [ "$status" -eq 0 ]

  run cat "${speech_log}"
  [ "$status" -eq 0 ]
  [ "$output" = "Explained: argument text" ]
}

@test "narrate: chunks long generated output before Piper synthesis" {
  local chunk_log="${TEST_TMPDIR}/narrate-chunks.log"

  make_stub "wl-paste" 'printf "%s" "$LAZY_READER_TEST_SELECTION"'
  make_stub "piper" '
    output=""
    while (($#)); do
      if [[ "$1" == "-f" ]]; then
        output="$2"
        shift 2
        continue
      fi
      shift
    done
    input="$(cat)"
    printf "%s\n--chunk--\n" "$input" >> "$LAZY_READER_TEST_CHUNK_LOG"
    if [[ "$output" == "-" ]]; then
      printf "wave-data"
    else
      printf "wave-data" > "$output"
    fi
  '
  make_stub "mpv" 'cat >/dev/null'

  run env \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    "LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS=18" \
    "LAZY_READER_NARRATE_MAX_CHARS=200" \
    "LAZY_READER_NARRATE_CMD=printf 'First generated sentence. Second generated sentence.'" \
    "LAZY_READER_TEST_SELECTION=source text" \
    "LAZY_READER_TEST_CHUNK_LOG=${chunk_log}" \
    "PATH=${PATH}" \
    bash "${SCRIPTS_DIR}/lazy-reader.sh" narrate

  [ "$status" -eq 0 ]
  run bash -c "grep -c '^--chunk--$' '${chunk_log}'"
  [ "$status" -eq 0 ]
  [ "$output" -gt 1 ]
  run bash -c "head -n 1 '${chunk_log}'"
  [ "$status" -eq 0 ]
  [ "$output" = "First generated" ]
}

@test "narrate: exits 0 and stops reading when already running" {
  sleep 100 &
  HELPER_PID=$!
  echo "$HELPER_PID" > "${XDG_RUNTIME_DIR}/lazy-reader.pid"
  run_lr narrate
  [ "$status" -eq 0 ]
  [ ! -f "${XDG_RUNTIME_DIR}/lazy-reader.pid" ]
  ! kill -0 "$HELPER_PID" 2>/dev/null
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
