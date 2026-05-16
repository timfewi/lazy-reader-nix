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
        '.model == \"x-ai/grok-voice-tts-1.0\" and .input == \$input and .voice == \"Eve\" and .response_format == \"mp3\" and (has(\"speed\") | not)' \
        '$TEST_TMPDIR/payload.json'
    "

  [ "$status" -eq 0 ]
}

@test "speak_text: openrouter payload includes optional native speed" {
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
    LAZY_READER_TTS_MODEL=openai/gpt-4o-mini-tts-2025-12-15 \
    LAZY_READER_TTS_VOICE=alloy \
    LAZY_READER_OPENROUTER_SPEED=1.3 \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/audio.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      speak_text 'hello' ''
      jq -e '.speed == 1.3' '$TEST_TMPDIR/payload.json'
    "

  [ "$status" -eq 0 ]
}

@test "speak_text: gemini openrouter TTS auto-selects PCM response format" {
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
printf "%s" "$output" > "$TEST_TMPDIR/output-path.txt"
printf "pcm-audio" > "$output"
'
  make_stub mpv 'exit 0'

  run env \
    "PATH=${PATH}" \
    "TEST_TMPDIR=${TEST_TMPDIR}" \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_OPENROUTER_API_KEY=test-key \
    LAZY_READER_TTS_PROVIDER=openrouter \
    LAZY_READER_TTS_MODEL=google/gemini-3.1-flash-tts-preview \
    LAZY_READER_TTS_VOICE=Zephyr \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/audio.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      speak_text 'hello' ''
      jq -e '.response_format == \"pcm\"' '$TEST_TMPDIR/payload.json'
      grep -q '.pcm$' '$TEST_TMPDIR/output-path.txt'
    "

  [ "$status" -eq 0 ]
}

@test "speak_text: explicit openrouter response format overrides gemini auto format" {
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
    LAZY_READER_TTS_MODEL=google/gemini-3.1-flash-tts-preview \
    LAZY_READER_TTS_VOICE=Zephyr \
    LAZY_READER_OPENROUTER_RESPONSE_FORMAT=mp3 \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/audio.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      speak_text 'hello' ''
      jq -e '.response_format == \"mp3\"' '$TEST_TMPDIR/payload.json'
    "

  [ "$status" -eq 0 ]
}

@test "speak_text: PCM response uses raw PCM mpv playback flags" {
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
printf "pcm-audio" > "$output"
'
  make_stub mpv 'printf "%s\n" "$*" > "$TEST_TMPDIR/mpv-args.txt"'

  run env \
    "PATH=${PATH}" \
    "TEST_TMPDIR=${TEST_TMPDIR}" \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_OPENROUTER_API_KEY=test-key \
    LAZY_READER_TTS_PROVIDER=openrouter \
    LAZY_READER_TTS_MODEL=google/gemini-3.1-flash-tts-preview \
    LAZY_READER_TTS_VOICE=Zephyr \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/audio.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      speak_text 'hello' ''
      grep -q -- '--demuxer=rawaudio' '$TEST_TMPDIR/mpv-args.txt'
      grep -q -- '--demuxer-rawaudio-format=s16le' '$TEST_TMPDIR/mpv-args.txt'
      grep -q -- '--demuxer-rawaudio-rate=24000' '$TEST_TMPDIR/mpv-args.txt'
      grep -q -- '--demuxer-rawaudio-channels=1' '$TEST_TMPDIR/mpv-args.txt'
    "

  [ "$status" -eq 0 ]
}

@test "speak_text: PCM response uses raw PCM ffplay playback flags" {
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
printf "pcm-audio" > "$output"
'
  make_stub ffplay 'printf "%s\n" "$*" > "$TEST_TMPDIR/ffplay-args.txt"'

  run env \
    "PATH=${PATH}" \
    "TEST_TMPDIR=${TEST_TMPDIR}" \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_PLAYER=ffplay \
    LAZY_READER_OPENROUTER_API_KEY=test-key \
    LAZY_READER_TTS_PROVIDER=openrouter \
    LAZY_READER_TTS_MODEL=google/gemini-3.1-flash-tts-preview \
    LAZY_READER_TTS_VOICE=Zephyr \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/audio.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      speak_text 'hello' ''
      grep -q -- '-f s16le' '$TEST_TMPDIR/ffplay-args.txt'
      grep -q -- '-ar 24000' '$TEST_TMPDIR/ffplay-args.txt'
      grep -q -- '-ac 1' '$TEST_TMPDIR/ffplay-args.txt'
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
