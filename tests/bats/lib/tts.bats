#!/usr/bin/env bats

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  MODEL_FILE="$(make_model_file)"
  export MODEL_FILE
}

teardown() {
  teardown_tmpdir
}

@test "speak_text: openrouter payload is valid JSON and preserves input text" {
  make_stub curl '
payload=""
output=""
while (($#)); do
  case "$1" in
    -d)
      payload="$2"
      shift 2
      ;;
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
printf "%s" "$payload" > "$TEST_TMPDIR/payload.json"
printf "audio" > "$output"
'
  make_stub mpv 'exit 0'

  run env \
    "PATH=${PATH}" \
    "TEST_TMPDIR=${TEST_TMPDIR}" \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_OPENROUTER_API_KEY=test-key \
    LAZY_READER_TTS_PROVIDER=openrouter \
    LAZY_READER_TTS_MODEL=x-ai/grok-voice-tts-1.0 \
    LAZY_READER_TTS_VOICE=Eve \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/audio.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      speak_text \$'hello \"world\"\nnext line' ''
      jq -e \
        --arg input \$'hello \"world\"\nnext line' \
        '.model == \"x-ai/grok-voice-tts-1.0\" and .input == \$input and .voice == \"Eve\" and .response_format == \"mp3\"' \
        '$TEST_TMPDIR/payload.json'
    "

  [ "$status" -eq 0 ]
}

@test "speak_text: openrouter failure reports HTTP status and response body" {
  make_stub curl '
output=""
while (($#)); do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
printf "{\"error\":\"invalid voice\"}" > "$output"
printf "400"
exit 22
'

  run env \
    "PATH=${PATH}" \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_OPENROUTER_API_KEY=test-key \
    LAZY_READER_TTS_PROVIDER=openrouter \
    LAZY_READER_TTS_MODEL=x-ai/grok-voice-tts-1.0 \
    LAZY_READER_TTS_VOICE=bad \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/audio.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      speak_text 'hello' ''
    "

  [ "$status" -ne 0 ]
  [[ "$output" == *"OpenRouter TTS request failed (HTTP 400): {\"error\":\"invalid voice\"}"* ]]
}
