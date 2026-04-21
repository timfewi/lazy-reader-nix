#!/usr/bin/env bats

load '../helpers/common'

REPO_ROOT="${BATS_TEST_DIRNAME}/../../.."
SCRIPT_PATH="${REPO_ROOT}/scripts/tmux-selection-provider.sh"

setup() {
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

@test "tmux selection provider: emits selected text from the best matching pane" {
  local tmux_log="${TEST_TMPDIR}/tmux.log"

  make_stub "tmux" '
    case "$1" in
      list-panes)
        printf "%%1\t1\t1\t0\t1\t0\n"
        printf "%%2\t1\t1\t1\t1\t1\n"
        ;;
      display-message)
        printf "1"
        ;;
      send-keys)
        printf "%s\n" "$*" >> "$LAZY_READER_TEST_TMUX_LOG"
        ;;
      show-buffer)
        printf "%s" "$LAZY_READER_TEST_TMUX_BUFFER_TEXT"
        ;;
      delete-buffer)
        printf "%s\n" "$*" >> "$LAZY_READER_TEST_TMUX_LOG"
        ;;
      *)
        exit 1
        ;;
    esac
  '

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_TEST_TMUX_LOG=${tmux_log}" \
    "LAZY_READER_TEST_TMUX_BUFFER_TEXT=selected from tmux" \
    bash "${SCRIPT_PATH}"

  [ "$status" -eq 0 ]
  [ "$output" = "selected from tmux" ]

  run cat "${tmux_log}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"send-keys -t %2 -X copy-pipe-and-cancel"* ]]
}

@test "tmux selection provider: respects explicit pane override" {
  local tmux_log="${TEST_TMPDIR}/tmux-override.log"

  make_stub "tmux" '
    case "$1" in
      display-message)
        printf "1"
        ;;
      send-keys)
        printf "%s\n" "$*" >> "$LAZY_READER_TEST_TMUX_LOG"
        ;;
      show-buffer)
        printf "override text"
        ;;
      delete-buffer)
        :
        ;;
      *)
        exit 1
        ;;
    esac
  '

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_TMUX_PANE=%9" \
    "LAZY_READER_TEST_TMUX_LOG=${tmux_log}" \
    bash "${SCRIPT_PATH}"

  [ "$status" -eq 0 ]
  [ "$output" = "override text" ]

  run cat "${tmux_log}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"send-keys -t %9 -X copy-pipe-and-cancel"* ]]
}

@test "tmux selection provider: exits non-zero when no pane has a selection" {
  make_stub "tmux" '
    case "$1" in
      list-panes)
        printf "%%1\t1\t1\t1\t0\t0\n"
        ;;
      display-message)
        printf "0"
        ;;
      delete-buffer)
        :
        ;;
      *)
        exit 1
        ;;
    esac
  '

  run env "PATH=${PATH}" bash "${SCRIPT_PATH}"
  [ "$status" -ne 0 ]
}
