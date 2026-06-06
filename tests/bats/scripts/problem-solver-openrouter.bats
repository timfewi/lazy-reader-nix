#!/usr/bin/env bats
# Tests for scripts/problem-solver-openrouter.sh
# Covers: input passthrough, payload shape, env-driven tuning, and curl failure.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "curl" '
    printf "%s\n" "$@" >> "$LAZY_READER_TEST_CURL_LOG"
    printf "{\"choices\":[{\"message\":{\"content\":\"spoken solution\"}}]}"
  '
  make_stub "jq" '
    if [[ "${1:-}" == "-n" ]]; then
      printf "%s\n" "$@" >> "$LAZY_READER_TEST_JQ_LOG"
      printf "{\"payload\":true}"
    else
      cat >/dev/null
      printf "spoken solution"
    fi
  '
}

teardown() {
  teardown_tmpdir
}

@test "problem-solver-openrouter helper: builds the troubleshooting payload" {
  local jq_log="${TEST_TMPDIR}/jq.log"
  local curl_log="${TEST_TMPDIR}/curl.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${curl_log}" \
    bash -c "printf '%s' 'Error: connection refused on port 8080' | bash '${SCRIPTS_DIR}/problem-solver-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken solution" ]

  run bash -c "grep -F -- 'Error: connection refused on port 8080' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'qwen/qwen3.6-flash' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '16000' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.12' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'You are a senior troubleshooting assistant.' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- 'Authorization: Bearer test-key' '${curl_log}'"
  [ "$status" -eq 0 ]
}

@test "problem-solver-openrouter helper: honors runtime tuning env vars" {
  local jq_log="${TEST_TMPDIR}/jq-override.log"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=test-key" \
    "LAZY_READER_PROBLEM_SOLVER_MODEL=custom/solver-model" \
    "LAZY_READER_PROBLEM_SOLVER_MAX_TOKENS=600" \
    "LAZY_READER_PROBLEM_SOLVER_TEMPERATURE=0.55" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-override.log" \
    bash -c "printf '%s' 'solver input' | bash '${SCRIPTS_DIR}/problem-solver-openrouter.sh'"

  [ "$status" -eq 0 ]
  [ "$output" = "spoken solution" ]

  run bash -c "grep -F -- 'custom/solver-model' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '600' '${jq_log}'"
  [ "$status" -eq 0 ]

  run bash -c "grep -F -- '0.55' '${jq_log}'"
  [ "$status" -eq 0 ]
}

@test "problem-solver-openrouter helper: exits non-zero when curl fails" {
  make_stub "curl" '
    exit 22
  '

  run env \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=bad-key" \
    "LAZY_READER_TEST_JQ_LOG=${TEST_TMPDIR}/jq-fail.log" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-fail.log" \
    bash -c "printf '%s' 'solver input' | bash '${SCRIPTS_DIR}/problem-solver-openrouter.sh'"

  [ "$status" -ne 0 ]
  [[ "$output" == *"OpenRouter API request failed. Check LAZY_READER_OPENROUTER_API_KEY and network."* ]]
}