#!/usr/bin/env bash
set -euo pipefail

tmux_bin="${LAZY_READER_TMUX_BIN:-tmux}"
buffer_name="lazy-reader-selection-$$"
requested_pane="${LAZY_READER_TMUX_PANE:-}"

if ! command -v "$tmux_bin" >/dev/null 2>&1; then
  exit 1
fi

pick_tmux_selection_pane() {
  local best_pane=""
  local best_score=-1
  local pane_id
  local session_attached
  local window_active
  local pane_active
  local pane_in_mode
  local selection_present
  local score

  while IFS=$'\t' read -r pane_id session_attached window_active pane_active pane_in_mode selection_present; do
    [[ "$selection_present" == "1" ]] || continue

    score=0
    [[ "$session_attached" == "1" ]] && ((score += 100))
    [[ "$window_active" == "1" ]] && ((score += 10))
    [[ "$pane_active" == "1" ]] && ((score += 5))
    [[ "$pane_in_mode" == "1" ]] && ((score += 1))

    if (( score > best_score )); then
      best_score=$score
      best_pane="$pane_id"
    fi
  done < <("$tmux_bin" list-panes -a -F '#{pane_id}\t#{session_attached}\t#{window_active}\t#{pane_active}\t#{pane_in_mode}\t#{selection_present}')

  printf '%s' "$best_pane"
}

pane_has_selection() {
  local pane="$1"
  [[ "$("$tmux_bin" display-message -p -t "$pane" '#{selection_present}' 2>/dev/null || printf '0')" == "1" ]]
}

target_pane="$requested_pane"
if [[ -z "$target_pane" ]]; then
  target_pane="$(pick_tmux_selection_pane)"
fi

[[ -n "$target_pane" ]] || exit 1
pane_has_selection "$target_pane" || exit 1

cleanup() {
  "$tmux_bin" delete-buffer -b "$buffer_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$tmux_bin" send-keys -t "$target_pane" -X copy-pipe-and-cancel "$tmux_bin load-buffer -b '$buffer_name' -"
"$tmux_bin" show-buffer -b "$buffer_name"
