#!/usr/bin/env bats

load '../helpers/common'

SET_TTS="${BATS_TEST_DIRNAME}/../../../scripts/lazy-reader-set-tts"

setup() {
  setup_tmpdir
  export XDG_CONFIG_HOME="${TEST_TMPDIR}/config"
}

teardown() {
  teardown_tmpdir
}

@test "lazy-reader-set-tts: writes runtime config" {
  run "$SET_TTS" openrouter x-ai/grok-voice-tts-1.0 alloy
  [ "$status" -eq 0 ]
  [ "$(cat "${XDG_CONFIG_HOME}/lazy-reader/tts.conf")" = $'TTS_PROVIDER=openrouter\nTTS_MODEL=x-ai/grok-voice-tts-1.0\nTTS_VOICE=alloy' ]
}

@test "lazy-reader-set-tts: rejects invalid provider" {
  run "$SET_TTS" bad model voice
  [ "$status" -ne 0 ]
}

@test "lazy-reader-set-tts: rejects newline values" {
  run "$SET_TTS" openrouter $'model\nbad' voice
  [ "$status" -ne 0 ]
}
