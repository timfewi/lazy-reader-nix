#!/usr/bin/env bats

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
}

teardown() {
  teardown_tmpdir
}

@test "resolve_input_text: auto prefers stdin over provider and GUI sources" {
  make_stub "wl-paste" 'printf "selected text"'

  run bash -c "
    source '${SCRIPTS_DIR}/lib/notify.sh'
    source '${SCRIPTS_DIR}/lib/input.sh'
    INPUT_SOURCE=auto
    INPUT_PROVIDER_CMD=\"printf '%s' 'provider text'\"
    resolve_input_text '' ''
  " <<< "stdin text"

  [ "$status" -eq 0 ]
  [ "$output" = "stdin text" ]
}

@test "resolve_input_text: auto prefers stdin over primary selection and clipboard" {
  make_stub "wl-paste" 'printf "selected text"'

  run bash -c "
    source '${SCRIPTS_DIR}/lib/notify.sh'
    source '${SCRIPTS_DIR}/lib/input.sh'
    INPUT_SOURCE=auto
    INPUT_PROVIDER_CMD=
    resolve_input_text '' ''
  " <<< "stdin text"

  [ "$status" -eq 0 ]
  [ "$output" = "stdin text" ]
}

@test "resolve_input_text: explicit clipboard source bypasses primary selection" {
  make_stub "wl-paste" '
    for arg in "$@"; do
      [[ "$arg" == "--primary" ]] && { printf "primary text"; exit 0; }
    done
    printf "clipboard text"
  '

  run bash -c "
    source '${SCRIPTS_DIR}/lib/notify.sh'
    source '${SCRIPTS_DIR}/lib/input.sh'
    resolve_input_text '' clipboard
  "

  [ "$status" -eq 0 ]
  [ "$output" = "clipboard text" ]
}

@test "resolve_input_text: explicit argument text wins when provided" {
  run bash -c "
    source '${SCRIPTS_DIR}/lib/notify.sh'
    source '${SCRIPTS_DIR}/lib/input.sh'
    resolve_input_text 'argument text' auto
  "

  [ "$status" -eq 0 ]
  [ "$output" = "argument text" ]
}

@test "resolve_input_text: auto falls through after provider failure without notifying" {
  export LAZY_READER_TEST_NOTIFY_LOG="${TEST_TMPDIR}/notify.log"
  make_stub "notify-send" '
    printf "%s\n" "$*" >> "$LAZY_READER_TEST_NOTIFY_LOG"
    printf "42"
  '
  make_stub "wl-paste" 'printf "selected text"'

  run bash -c "
    source '${SCRIPTS_DIR}/lib/notify.sh'
    source '${SCRIPTS_DIR}/lib/input.sh'
    INPUT_SOURCE=auto
    INPUT_PROVIDER_CMD=false
    resolve_input_text '' ''
  "

  [ "$status" -eq 0 ]
  [ "$output" = "selected text" ]
  [ ! -e "${LAZY_READER_TEST_NOTIFY_LOG}" ]
}

@test "resolve_input_text: explicit provider failure stays actionable" {
  export NOTIFY_TITLE="Lazy Reader"
  export LAZY_READER_TEST_NOTIFY_LOG="${TEST_TMPDIR}/notify.log"
  make_stub "notify-send" '
    printf "%s\n" "$*" >> "$LAZY_READER_TEST_NOTIFY_LOG"
    printf "42"
  '

  run bash -c "
    source '${SCRIPTS_DIR}/lib/notify.sh'
    source '${SCRIPTS_DIR}/lib/input.sh'
    INPUT_PROVIDER_CMD=false
    resolve_input_text '' provider
  "

  [ "$status" -eq 1 ]
  [[ "$output" == *"Input provider command failed. Check LAZY_READER_INPUT_PROVIDER_CMD."* ]]
  [ ! -e "${LAZY_READER_TEST_NOTIFY_LOG}" ]
}
