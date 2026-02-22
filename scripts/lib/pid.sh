#!/usr/bin/env bash

is_running() {
  [[ -f "$PID_FILE" ]] || return 1

  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1

  kill -0 "$pid" 2>/dev/null
}

cleanup_stale_pid_file() {
  if [[ -f "$PID_FILE" ]] && ! is_running; then
    rm -f "$PID_FILE"
  fi
}

_kill_descendants() {
  local pid="$1" sig="$2"
  local child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    _kill_descendants "$child" "$sig"
  done
  kill "-$sig" "$pid" 2>/dev/null || true
}

kill_reader_tree() {
  local pid="$1"

  _kill_descendants "$pid" TERM

  for _ in {1..30}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.05
  done

  if kill -0 "$pid" 2>/dev/null; then
    _kill_descendants "$pid" KILL
  fi
}

stop_running_reader() {
  cleanup_stale_pid_file

  if ! is_running; then
    rm -f "$PID_FILE"
    notify "Nothing is reading right now."
    return 0
  fi

  local pid
  pid="$(cat "$PID_FILE")"
  kill_reader_tree "$pid"
  rm -f "$PID_FILE"
  notify "Stopped reading."
}

cleanup() {
  if [[ -n "$PLAYER_PID" ]] && kill -0 "$PLAYER_PID" 2>/dev/null; then
    kill -TERM "$PLAYER_PID" 2>/dev/null || true
  fi

  if [[ -n "$RESPONSE_FILE" ]]; then
    rm -f "$RESPONSE_FILE"
  fi

  if [[ -n "$MODEL_DIR" ]]; then
    rm -rf "$MODEL_DIR"
  fi

  if [[ "$OWNS_PID_FILE" == "1" ]] && [[ -f "$PID_FILE" ]]; then
    local owner
    owner="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ "$owner" == "$$" ]]; then
      rm -f "$PID_FILE"
    fi
  fi
}
