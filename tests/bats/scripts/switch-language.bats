#!/usr/bin/env bats
# Tests for `lazy-reader switch <language>` and the LAZY_READER_LANG_DIRECTIVE
# it drives: persisting lang.conf + tts.conf, validating the language, and the
# directive being appended to an *-openrouter.sh prompt (and absent by default).

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  make_stub "notify-send"
}

teardown() {
  teardown_tmpdir
}

run_lr() {
  run env \
    "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}" \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "PATH=${PATH}" \
    bash "${SCRIPTS_DIR}/lazy-reader.sh" "$@"
}

@test "switch german: writes lang.conf and points TTS at the fast kokoro voice" {
  run_lr switch german
  [ "$status" -eq 0 ]
  run cat "${XDG_CONFIG_HOME}/lazy-reader/lang.conf"
  [ "$output" = "LANGUAGE=de" ]
  run cat "${XDG_CONFIG_HOME}/lazy-reader/tts.conf"
  [[ "$output" == *"TTS_MODEL=hexgrad/kokoro-82m"* ]]
  [[ "$output" == *"TTS_VOICE=af_heart"* ]]
}

@test "switch english: restores the kokoro default" {
  run_lr switch english
  [ "$status" -eq 0 ]
  run cat "${XDG_CONFIG_HOME}/lazy-reader/lang.conf"
  [ "$output" = "LANGUAGE=en" ]
  run cat "${XDG_CONFIG_HOME}/lazy-reader/tts.conf"
  [[ "$output" == *"TTS_MODEL=hexgrad/kokoro-82m"* ]]
  [[ "$output" == *"TTS_VOICE=af_heart"* ]]
}

@test "switch deutsch: accepts the native-language alias" {
  run_lr switch deutsch
  [ "$status" -eq 0 ]
  run cat "${XDG_CONFIG_HOME}/lazy-reader/lang.conf"
  [ "$output" = "LANGUAGE=de" ]
}

@test "switch: rejects an unknown language and writes nothing" {
  run_lr switch klingon
  [ "$status" -ne 0 ]
  [ ! -f "${XDG_CONFIG_HOME}/lazy-reader/lang.conf" ]
}

@test "switch: requires a language argument" {
  run_lr switch
  [ "$status" -ne 0 ]
}

@test "openrouter prompt: appends the directive when one is set" {
  local jq_log="${TEST_TMPDIR}/jq.log"
  make_stub "curl" 'printf "{\"choices\":[{\"message\":{\"content\":\"x\"}}]}"'
  make_openrouter_jq_stub "x"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=k" \
    "LAZY_READER_LANG_DIRECTIVE=ANTWORTE_AUF_DEUTSCH" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl.log" \
    bash -c "printf '%s' 'let x = sum(items);' | bash '${SCRIPTS_DIR}/narrate-openrouter.sh'"

  [ "$status" -eq 0 ]
  run bash -c "grep -F -- 'ANTWORTE_AUF_DEUTSCH' '${jq_log}'"
  [ "$status" -eq 0 ]
}

@test "openrouter prompt: no directive text leaks when unset" {
  local jq_log="${TEST_TMPDIR}/jq-plain.log"
  make_stub "curl" 'printf "{\"choices\":[{\"message\":{\"content\":\"x\"}}]}"'
  make_openrouter_jq_stub "x"

  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_OPENROUTER_API_KEY=k" \
    "LAZY_READER_TEST_JQ_LOG=${jq_log}" \
    "LAZY_READER_TEST_CURL_LOG=${TEST_TMPDIR}/curl-plain.log" \
    bash -c "printf '%s' 'let x = sum(items);' | bash '${SCRIPTS_DIR}/narrate-openrouter.sh'"

  [ "$status" -eq 0 ]
  run bash -c "grep -F -- 'ANTWORTE_AUF_DEUTSCH' '${jq_log}'"
  [ "$status" -ne 0 ]
}
