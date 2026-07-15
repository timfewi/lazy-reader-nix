#!/usr/bin/env bash

notify() {
  local message="$1"
  # Optional expire-time in ms (default 1000). Pass a longer value for a
  # "still working…" toast that must stay visible across a slow round-trip.
  local expire="${2:-1000}"
  printf '%s\n' "[$NOTIFY_TITLE] $message" >&2
  if command -v notify-send >/dev/null 2>&1; then
    local -a args=(--expire-time="$expire" --print-id)
    [[ -n "${NOTIFY_ID:-}" ]] && args+=(--replace-id="$NOTIFY_ID")
    if NOTIFY_ID="$(notify-send "${args[@]}" "$NOTIFY_TITLE" "$message")"; then
      NOTIFY_ID="${NOTIFY_ID//$'\n'/}"
    else
      NOTIFY_ID=""
    fi
  fi
}
