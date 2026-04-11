#!/usr/bin/env bash

notify() {
  local message="$1"
  printf '%s\n' "[$NOTIFY_TITLE] $message" >&2
  if command -v notify-send >/dev/null 2>&1; then
    if [[ -n "${NOTIFY_ID:-}" ]]; then
      if NOTIFY_ID="$(
        notify-send \
          --expire-time=1000 \
          --replace-id="$NOTIFY_ID" \
          --print-id \
          "$NOTIFY_TITLE" \
          "$message"
      )"; then
        NOTIFY_ID="${NOTIFY_ID//$'\n'/}"
      else
        NOTIFY_ID=""
      fi
    else
      if NOTIFY_ID="$(
        notify-send \
          --expire-time=1000 \
          --print-id \
          "$NOTIFY_TITLE" \
          "$message"
      )"; then
        NOTIFY_ID="${NOTIFY_ID//$'\n'/}"
      else
        NOTIFY_ID=""
      fi
    fi
  fi
}
