#!/usr/bin/env bash

notify() {
  local message="$1"
  printf '%s\n' "[$NOTIFY_TITLE] $message" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$NOTIFY_TITLE" "$message"
  fi
}
