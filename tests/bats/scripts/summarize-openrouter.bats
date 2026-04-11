#!/usr/bin/env bats
# Tests for scripts/summarize-openrouter.sh
# Covers: input passthrough into the OpenRouter payload, env-driven tuning, and curl failure handling.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "curl" '
    printf "%s\n" "$@" >> "$LAZY_READER_TEST_CURL_LOG"
    printf "{\"choices\":[{\"message\":{\"content\":\"spoken summary\"}}]}"
  '
  make_stub "jq" '
    if [[ "${1:-}" == "-n" ]]; then
      printf "%s\n" "$@" >> "$LAZY_READER_TEST_JQ_LOG"
      printf "{\"payload\":true}"
    else
      cat >/dev/null
      printf "spoken summary"
    fi
  '
}

teardown() {
  teardown_tmpdir
}

@test "summarize-openrouter helper: builds the spoken-summary payload" {
  local jq_log="${TEST_TMPDIR}/jq.log"
  local curl_log="${TEST_TMPDIR}/curl.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${curl_log}" \
    bash -c "printf '%s' 'A detailed technical passage.' | bash '${SCRIPTS_DIR}/summarize-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken summary" ]

  run bash -c "grep -F -- 'A detailed technical passage.' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'openai/gpt-5.4-mini' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '3200' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.12' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'Summarize the following passage for listening aloud.' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'Authorization: Bearer test-key' '${curl_log}'"
  [ "$status" -eq 0 ]
}

@test "summarize-openrouter helper: honors runtime model overrides" {
  local jq_log="${TEST_TMPDIR}/jq-override.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_SUMMARIZE_MODEL=custom/summary-model" \
    "LAZY_READER_SUMMARIZE_MAX_TOKENS=900" \
    "LAZY_READER_SUMMARIZE_TEMPERATURE=0.33" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-override.log" \
    bash -c "printf '%s' 'summary input' | bash '${SCRIPTS_DIR}/summarize-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken summary" ]

  run bash -c "grep -F -- 'custom/summary-model' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '900' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.33' '${jq_log}'"
  [ "$status" -eq 0 ]
}

@test "summarize-openrouter helper: exits non-zero when curl fails" {
  make_stub "curl" '
    exit 22
  '

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=bad-key" \
    "LAZY_READER_TEST_JQ_LOG=${TEST_TMPDIR}/jq-fail.log" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-fail.log" \
    bash -c "printf '%s' 'summary input' | bash '${SCRIPTS_DIR}/summarize-openrouter.sh'"

  [ "$status" -ne 0 ]
  [[ "$output" == *"OpenRouter API request failed. Check LAZY_READER_OPENROUTER_API_KEY and network."* ]]
}
