#!/usr/bin/env bats
# Tests for scripts/ask-openrouter.sh
# Covers: input+question passthrough, payload shape, env-driven tuning, and curl failure.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "curl" '
    printf "%s\n" "$@" >> "$LAZY_READER_TEST_CURL_LOG"
    printf "{\"choices\":[{\"message\":{\"content\":\"spoken answer\"}}]}"
  '
  make_stub "jq" '
    if [[ "${1:-}" == "-n" ]]; then
      printf "%s\n" "$@" >> "$LAZY_READER_TEST_JQ_LOG"
      printf "{\"payload\":true}"
    else
      cat >/dev/null
      printf "spoken answer"
    fi
  '
}

teardown() {
  teardown_tmpdir
}

@test "ask-openrouter helper: builds the question-answering payload" {
  local jq_log="${TEST_TMPDIR}/jq.log"
  local curl_log="${TEST_TMPDIR}/curl.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_ASK_QUESTION=What does this function do?" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${curl_log}" \
    bash -c "printf '%s' 'def add(a, b): return a + b' | bash '${SCRIPTS_DIR}/ask-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken answer" ]

  run bash -c "grep -F -- 'def add(a, b): return a + b' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'What does this function do?' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'qwen/qwen3.6-flash' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '12000' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.2' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'You are a helpful assistant answering a question about a piece of text.' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'Authorization: Bearer test-key' '${curl_log}'"
  [ "$status" -eq 0 ]
}

@test "ask-openrouter helper: honors runtime tuning env vars" {
  local jq_log="${TEST_TMPDIR}/jq-override.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_ASK_MODEL=custom/ask-model" \
    "LAZY_READER_ASK_MAX_TOKENS=700" \
    "LAZY_READER_ASK_TEMPERATURE=0.45" \
    "LAZY_READER_ASK_QUESTION=What is this?" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-override.log" \
    bash -c "printf '%s' 'some context' | bash '${SCRIPTS_DIR}/ask-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken answer" ]

  run bash -c "grep -F -- 'custom/ask-model' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '700' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.45' '${jq_log}'"
  [ "$status" -eq 0 ]
}

@test "ask-openrouter helper: exits non-zero when curl fails" {
  make_stub "curl" '
    exit 22
  '

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=bad-key" \
    "LAZY_READER_ASK_QUESTION=test" \
    "LAZY_READER_TEST_JQ_LOG=${TEST_TMPDIR}/jq-fail.log" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-fail.log" \
    bash -c "printf '%s' 'input' | bash '${SCRIPTS_DIR}/ask-openrouter.sh'"

  [ "$status" -ne 0 ]
  [[ "$output" == *"OpenRouter API request failed. Check LAZY_READER_OPENROUTER_API_KEY and network."* ]]
}