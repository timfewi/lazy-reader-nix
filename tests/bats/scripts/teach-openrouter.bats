#!/usr/bin/env bats
# Tests for scripts/teach-openrouter.sh
# Covers: input passthrough, payload shape, env-driven tuning, and curl failure.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "curl" '
    printf "%s\n" "$@" >> "$LAZY_READER_TEST_CURL_LOG"
    printf "{\"choices\":[{\"message\":{\"content\":\"spoken explanation\"}}]}"
  '
  make_stub "jq" '
    if [[ "${1:-}" == "-n" ]]; then
      printf "%s\n" "$@" >> "$LAZY_READER_TEST_JQ_LOG"
      printf "{\"payload\":true}"
    else
      cat >/dev/null
      printf "spoken explanation"
    fi
  '
}

teardown() {
  teardown_tmpdir
}

@test "teach-openrouter helper: builds the ELI5 payload" {
  local jq_log="${TEST_TMPDIR}/jq.log"
  local curl_log="${TEST_TMPDIR}/curl.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${curl_log}" \
    bash -c "printf '%s' 'A closure is a function that captures variables from its surrounding scope.' | bash '${SCRIPTS_DIR}/teach-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken explanation" ]

  run bash -c "grep -F -- 'A closure is a function that captures variables from its surrounding scope.' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'qwen/qwen3.7-plus' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '18000' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.2' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'You are helping someone understand a page from a programming book.' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'Authorization: Bearer test-key' '${curl_log}'"
  [ "$status" -eq 0 ]
}

@test "teach-openrouter helper: honors runtime tuning env vars" {
  local jq_log="${TEST_TMPDIR}/jq-override.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_TEACH_MODEL=custom/teach-model" \
    "LAZY_READER_TEACH_MAX_TOKENS=500" \
    "LAZY_READER_TEACH_TEMPERATURE=0.66" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-override.log" \
    bash -c "printf '%s' 'teach input' | bash '${SCRIPTS_DIR}/teach-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken explanation" ]

  run bash -c "grep -F -- 'custom/teach-model' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '500' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.66' '${jq_log}'"
  [ "$status" -eq 0 ]
}

@test "teach-openrouter helper: exits non-zero when curl fails" {
  make_stub "curl" '
    exit 22
  '

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=bad-key" \
    "LAZY_READER_TEST_JQ_LOG=${TEST_TMPDIR}/jq-fail.log" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-fail.log" \
    bash -c "printf '%s' 'teach input' | bash '${SCRIPTS_DIR}/teach-openrouter.sh'"

  [ "$status" -ne 0 ]
  [[ "$output" == *"OpenRouter API request failed. Check LAZY_READER_OPENROUTER_API_KEY and network."* ]]
}