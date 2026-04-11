#!/usr/bin/env bats
# Tests for scripts/lib/notify.sh
# Covers: transient desktop notifications and replacement of prior notifications.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  export NOTIFY_TITLE="Lazy Reader"
  export NOTIFY_ID=""
  make_stub "notify-send" '
    printf "%s\n" "$*" >> "$LAZY_READER_TEST_NOTIFY_LOG"
    printf "42"
  '
  # shellcheck source=scripts/lib/notify.sh
  source "${SCRIPTS_DIR}/lib/notify.sh"
}

teardown() {
  teardown_tmpdir
}

@test "notify: uses a 1 second expiration" {
  export LAZY_READER_TEST_NOTIFY_LOG="${TEST_TMPDIR}/notify.log"

  notify "First message"

  run bash -c "grep -F -- '--expire-time=1000' '${LAZY_READER_TEST_NOTIFY_LOG}'"
  [ "$status" -eq 0 ]
}

@test "notify: replaces the previous notification id" {
  export LAZY_READER_TEST_NOTIFY_LOG="${TEST_TMPDIR}/notify.log"

  notify "First message"
  notify "Second message"

  run bash -c "sed -n '2p' '${LAZY_READER_TEST_NOTIFY_LOG}'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--replace-id=42"* ]]
}
