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
    LAZY_READER_SPEAKER=0 \
    LAZY_READER_MAX_CHARS=100 \
    LAZY_READER_EXPLAIN_MAX_CHARS=100 \
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    "$@" \
    bash -c "
      source '${SCRIPTS_DIR}/lib/notify.sh'
      source '${SCRIPTS_DIR}/lib/config.sh'
      source '${SCRIPTS_DIR}/lib/tts.sh'
      validate_config
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

@test "validate_config: accepts SPEED alias 'normal'" {
  run_validate LAZY_READER_SPEED=normal
  [ "$status" -eq 0 ]
}

@test "validate_config: fails when legacy PLAYBACK_SPEED is unknown text" {
  run_validate LAZY_READER_SPEED= LAZY_READER_PLAYBACK_SPEED=turbo
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
