#!/usr/bin/env bats
# Tests for scripts/narrate-openrouter.sh
# Covers: input passthrough into the OpenRouter payload, prompt shape, and env-driven tuning.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "curl" '
    printf "%s\n" "$@" >> "$LAZY_READER_TEST_CURL_LOG"
    printf "{\"choices\":[{\"message\":{\"content\":\"spoken narration\"}}]}"
  '
  make_stub "jq" '
    if [[ "${1:-}" == "-n" ]]; then
      printf "%s\n" "$@" >> "$LAZY_READER_TEST_JQ_LOG"
      printf "{\"payload\":true}"
    else
      cat >/dev/null
      printf "spoken narration"
    fi
  '
}

teardown() {
  teardown_tmpdir
}

@test "narrate-openrouter helper: builds the faithful narrated-docs payload" {
  local jq_log="${TEST_TMPDIR}/jq.log"
  local curl_log="${TEST_TMPDIR}/curl.log"

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${curl_log}" \
    bash -c "printf '%s' 'let total = sum(items);' | bash '${SCRIPTS_DIR}/narrate-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken narration" ]

  run bash -c "grep -F -- 'let total = sum(items);' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'x-ai/grok-4.1-fast' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '1800' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.12' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'You are a faithful spoken renderer of technical documentation and source code.' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'Do not invent behavior, examples, missing context, or background knowledge' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'preserve every identifier, function name, option name, flag, exact value, file path, and command' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'Authorization: Bearer test-key' '${curl_log}'"
  [ "$status" -eq 0 ]
}

@test "narrate-openrouter helper: honors runtime tuning env vars" {
  local jq_log="${TEST_TMPDIR}/jq-override.log"

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_NARRATE_MODEL=custom/model" \
    "LAZY_READER_NARRATE_MAX_TOKENS=900" \
    "LAZY_READER_NARRATE_TEMPERATURE=0.33" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-override.log" \
    bash -c "printf '%s' 'docs input' | bash '${SCRIPTS_DIR}/narrate-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken narration" ]

  run bash -c "grep -F -- 'custom/model' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '900' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.33' '${jq_log}'"
  [ "$status" -eq 0 ]
}
