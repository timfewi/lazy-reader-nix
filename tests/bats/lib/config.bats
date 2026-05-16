#!/usr/bin/env bats
# Tests for validate_config (scripts/lib/tts.sh).
# Each test runs validate_config in a clean subprocess so that the readonly
# variables set by config.sh don't bleed between cases.

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

# Helper: run validate_config in a subprocess with all valid defaults.
# Pass extra VAR=value overrides as arguments to inject invalid values.
run_validate() {
  run env \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_SPEED=1.4 \
    LAZY_READER_PLAYBACK_SPEED=1.0 \
    LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS=100 \
    LAZY_READER_SPEAKER=0 \
    LAZY_READER_MAX_CHARS=100 \
    LAZY_READER_NARRATE_INPUT_MAX_CHARS=100 \
    LAZY_READER_NARRATE_MAX_CHARS=100 \
    LAZY_READER_EXPLAIN_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS=100 \
    LAZY_READER_PROBLEM_SOLVER_MAX_CHARS=100 \
    LAZY_READER_ASK_MAX_CHARS=100 \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "$@" \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      validate_config
    "
}

run_config_dump() {
  run env \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_SPEED=1.4 \
    LAZY_READER_PLAYBACK_SPEED=1.0 \
    LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS=100 \
    LAZY_READER_SPEAKER=0 \
    LAZY_READER_MAX_CHARS=100 \
    LAZY_READER_NARRATE_INPUT_MAX_CHARS=100 \
    LAZY_READER_NARRATE_MAX_CHARS=100 \
    LAZY_READER_EXPLAIN_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS=100 \
    LAZY_READER_PROBLEM_SOLVER_MAX_CHARS=100 \
    LAZY_READER_ASK_MAX_CHARS=100 \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "$@" \
    bash -c "
      source '${SCRIPTS_DIR}/lib/config.sh'
      printf 'SPEED=%s\nPLAYBACK_SPEED=%s\n' \"\$SPEED\" \"\$PLAYBACK_SPEED\"
    "
}

run_tts_config_dump() {
  run env \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_SPEED=1.4 \
    LAZY_READER_PLAYBACK_SPEED=1.0 \
    LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS=100 \
    LAZY_READER_SPEAKER=0 \
    LAZY_READER_MAX_CHARS=100 \
    LAZY_READER_NARRATE_INPUT_MAX_CHARS=100 \
    LAZY_READER_NARRATE_MAX_CHARS=100 \
    LAZY_READER_EXPLAIN_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS=100 \
    LAZY_READER_PROBLEM_SOLVER_MAX_CHARS=100 \
    LAZY_READER_ASK_MAX_CHARS=100 \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "XDG_CONFIG_HOME=${TEST_TMPDIR}/config" \
    "$@" \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      load_tts_config
      printf 'TTS_PROVIDER=%s\nTTS_MODEL=%s\nTTS_VOICE=%s\n' \"\$TTS_PROVIDER\" \"\$TTS_MODEL\" \"\$TTS_VOICE\"
    "
}

run_openrouter_key_dump() {
  run env -i \
    "PATH=${PATH}" \
    "LAZY_READER_MODEL=${MODEL_FILE}" \
    LAZY_READER_SPEED=1.4 \
    LAZY_READER_PLAYBACK_SPEED=1.0 \
    LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS=100 \
    LAZY_READER_SPEAKER=0 \
    LAZY_READER_MAX_CHARS=100 \
    LAZY_READER_NARRATE_INPUT_MAX_CHARS=100 \
    LAZY_READER_NARRATE_MAX_CHARS=100 \
    LAZY_READER_EXPLAIN_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_MAX_CHARS=100 \
    LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS=100 \
    LAZY_READER_PROBLEM_SOLVER_MAX_CHARS=100 \
    LAZY_READER_ASK_MAX_CHARS=100 \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "$@" \
    bash -c "
      source '${SCRIPTS_DIR}/lib/config.sh'
      printf 'OPENROUTER_API_KEY=%s\n' \"\$LAZY_READER_OPENROUTER_API_KEY\"
    "
}

# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

@test "validate_config: passes with valid defaults and existing model" {
  run_validate
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# SPEED validation
# ---------------------------------------------------------------------------

@test "validate_config: fails when SPEED is non-numeric" {
  run_validate LAZY_READER_SPEED=abc
  [ "$status" -ne 0 ]
}

@test "validate_config: passes when SPEED env var is empty (falls back to default)" {
  # Empty env var triggers ${LAZY_READER_SPEED:-1.4} substitution in config.sh.
  run_validate LAZY_READER_SPEED=
  [ "$status" -eq 0 ]
}

@test "validate_config: passes with integer SPEED" {
  run_validate LAZY_READER_SPEED=2
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Legacy playback speed env fallback
# ---------------------------------------------------------------------------

@test "validate_config: accepts legacy PLAYBACK_SPEED alias 'fast'" {
  run_validate LAZY_READER_SPEED= LAZY_READER_PLAYBACK_SPEED=fast
  [ "$status" -eq 0 ]
}

@test "config: LAZY_READER_SPEED does not also change PLAYBACK_SPEED by default" {
  run_config_dump LAZY_READER_SPEED=1.3 LAZY_READER_PLAYBACK_SPEED=
  [ "$status" -eq 0 ]
  [ "$output" = $'SPEED=1.3\nPLAYBACK_SPEED=1.0' ]
}

@test "config: legacy PLAYBACK_SPEED still backfills SPEED when SPEED is unset" {
  run_config_dump LAZY_READER_SPEED= LAZY_READER_PLAYBACK_SPEED=1.2
  [ "$status" -eq 0 ]
  [ "$output" = $'SPEED=1.2\nPLAYBACK_SPEED=1.2' ]
}

@test "config: loads OpenRouter API key from runtime file when env var is unset" {
  local key_file="${TEST_TMPDIR}/openrouter.key"
  printf '%s' 'test-openrouter-key' > "$key_file"

  run_openrouter_key_dump LAZY_READER_OPENROUTER_API_KEY_FILE="$key_file"
  [ "$status" -eq 0 ]
  [ "$output" = 'OPENROUTER_API_KEY=test-openrouter-key' ]
}

@test "config: TTS env defaults are exposed as runtime TTS config" {
  run_tts_config_dump \
    LAZY_READER_TTS_PROVIDER=openrouter \
    LAZY_READER_TTS_MODEL=x-ai/grok-voice-tts-1.0 \
    LAZY_READER_TTS_VOICE=alloy
  [ "$status" -eq 0 ]
  [ "$output" = $'TTS_PROVIDER=openrouter\nTTS_MODEL=x-ai/grok-voice-tts-1.0\nTTS_VOICE=alloy' ]
}

@test "config: runtime TTS config overrides env defaults" {
  mkdir -p "${TEST_TMPDIR}/config/lazy-reader"
  cat > "${TEST_TMPDIR}/config/lazy-reader/tts.conf" <<'EOF'
TTS_PROVIDER=piper
TTS_MODEL=local-model
TTS_VOICE=local-voice
EOF

  run_tts_config_dump \
    LAZY_READER_TTS_PROVIDER=openrouter \
    LAZY_READER_TTS_MODEL=x-ai/grok-voice-tts-1.0 \
    LAZY_READER_TTS_VOICE=alloy
  [ "$status" -eq 0 ]
  [ "$output" = $'TTS_PROVIDER=piper\nTTS_MODEL=local-model\nTTS_VOICE=local-voice' ]
}

@test "config: invalid runtime TTS provider fails" {
  mkdir -p "${TEST_TMPDIR}/config/lazy-reader"
  printf 'TTS_PROVIDER=bad\n' > "${TEST_TMPDIR}/config/lazy-reader/tts.conf"

  run_tts_config_dump
  [ "$status" -ne 0 ]
}

@test "config: runtime TTS config is parsed as data, not sourced" {
  mkdir -p "${TEST_TMPDIR}/config/lazy-reader"
  printf 'TTS_PROVIDER=openrouter\nTTS_MODEL=$(touch "%s/pwned")\nTTS_VOICE=alloy\n' "$TEST_TMPDIR" > "${TEST_TMPDIR}/config/lazy-reader/tts.conf"

  run_tts_config_dump
  [ "$status" -eq 0 ]
  [ ! -e "${TEST_TMPDIR}/pwned" ]
}

@test "validate_config: openrouter provider skips Piper model validation" {
  run_validate \
    LAZY_READER_MODEL=/nonexistent/fake.onnx \
    LAZY_READER_TTS_PROVIDER=openrouter
  [ "$status" -eq 0 ]
}

@test "validate_config: accepts SPEED alias 'normal'" {
  run_validate LAZY_READER_SPEED=normal
  [ "$status" -eq 0 ]
}

@test "validate_config: fails when legacy PLAYBACK_SPEED is unknown text" {
  run_validate LAZY_READER_SPEED= LAZY_READER_PLAYBACK_SPEED=turbo
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when PLAYBACK_SPEED is zero" {
  run_validate LAZY_READER_PLAYBACK_SPEED=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when GENERATED_SPEECH_CHUNK_MAX_CHARS is zero" {
  run_validate LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when GENERATED_SPEECH_CHUNK_MAX_CHARS is non-numeric" {
  run_validate LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS=lots
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# SPEAKER validation
# ---------------------------------------------------------------------------

@test "validate_config: fails when SPEAKER is non-integer" {
  run_validate LAZY_READER_SPEAKER=one
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when SPEAKER is a float" {
  run_validate LAZY_READER_SPEAKER=1.5
  [ "$status" -ne 0 ]
}

@test "validate_config: passes with speaker 0" {
  run_validate LAZY_READER_SPEAKER=0
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# MAX_CHARS validation
# ---------------------------------------------------------------------------

@test "validate_config: fails when MAX_CHARS is zero" {
  run_validate LAZY_READER_MAX_CHARS=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when MAX_CHARS is non-numeric" {
  run_validate LAZY_READER_MAX_CHARS=lots
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when NARRATE_MAX_CHARS is zero" {
  run_validate LAZY_READER_NARRATE_MAX_CHARS=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when NARRATE_MAX_CHARS is non-numeric" {
  run_validate LAZY_READER_NARRATE_MAX_CHARS=lots
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when NARRATE_INPUT_MAX_CHARS is zero" {
  run_validate LAZY_READER_NARRATE_INPUT_MAX_CHARS=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when NARRATE_INPUT_MAX_CHARS is non-numeric" {
  run_validate LAZY_READER_NARRATE_INPUT_MAX_CHARS=lots
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when ASK_MAX_CHARS is zero" {
  run_validate LAZY_READER_ASK_MAX_CHARS=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when ASK_MAX_CHARS is non-numeric" {
  run_validate LAZY_READER_ASK_MAX_CHARS=lots
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when SUMMARIZE_MAX_CHARS is zero" {
  run_validate LAZY_READER_SUMMARIZE_MAX_CHARS=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when SUMMARIZE_MAX_CHARS is non-numeric" {
  run_validate LAZY_READER_SUMMARIZE_MAX_CHARS=lots
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when SUMMARIZE_INPUT_MAX_CHARS is zero" {
  run_validate LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS=0
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when SUMMARIZE_INPUT_MAX_CHARS is non-numeric" {
  run_validate LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS=lots
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# MODEL file validation
# ---------------------------------------------------------------------------

@test "validate_config: fails when MODEL file does not exist" {
  run_validate LAZY_READER_MODEL=/nonexistent/fake.onnx
  [ "$status" -ne 0 ]
}

@test "validate_config: fails when MODEL_CONFIG is set but file does not exist" {
  run_validate LAZY_READER_MODEL_CONFIG=/nonexistent/fake.onnx.json
  [ "$status" -ne 0 ]
}

@test "validate_config: passes when MODEL_CONFIG is empty" {
  run_validate LAZY_READER_MODEL_CONFIG=
  [ "$status" -eq 0 ]
}
