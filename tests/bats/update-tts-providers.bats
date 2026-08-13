#!/usr/bin/env bats

load 'helpers/common'

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
UPDATER="${REPO_ROOT}/scripts/update-openrouter-tts-providers.sh"

setup() {
  setup_tmpdir
  API_DIR="${TEST_TMPDIR}/api"
  mkdir -p "${API_DIR}/example" "${TEST_TMPDIR}/docs" "${TEST_TMPDIR}/scripts"
  cat > "${API_DIR}/models.json" <<'EOF'
{"data":[{"id":"example/voice","architecture":{"output_modalities":["speech"]}},{"id":"example/text","architecture":{"output_modalities":["text"]}}]}
EOF
  cat > "${API_DIR}/example/voice.json" <<'EOF'
{"data":{"id":"example/voice","name":"Example Voice","supported_tts_voices":["calm","bright"]}}
EOF
  UPDATER_COPY="${TEST_TMPDIR}/scripts/update-openrouter-tts-providers.sh"
  cp "${UPDATER}" "${UPDATER_COPY}"
  DOC="${TEST_TMPDIR}/docs/tts-providers.md"
  cat > "${DOC}" <<'EOF'
# TTS

<!-- BEGIN OPENROUTER_TTS_MODELS -->
old
<!-- END OPENROUTER_TTS_MODELS -->
EOF
}

teardown() {
  teardown_tmpdir
}

run_updater() {
  run env \
    "OPENROUTER_MODELS_URL=file://${API_DIR}/models.json" \
    "OPENROUTER_MODEL_URL_TEMPLATE=file://${API_DIR}/{model}.json" \
    bash "${UPDATER_COPY}" "$@"
}

@test "updater writes only speech models and their published voices" {
  run_updater
  [ "$status" -eq 0 ]
  run grep -F '`example/voice`' "${DOC}"
  [ "$status" -eq 0 ]
  run grep -F '`bright`, `calm`' "${DOC}"
  [ "$status" -eq 0 ]
  run grep -F 'example/text' "${DOC}"
  [ "$status" -ne 0 ]
}

@test "updater --check succeeds after a refresh" {
  run_updater
  [ "$status" -eq 0 ]
  run_updater --check
  [ "$status" -eq 0 ]
}

@test "updater --check reports an outdated catalogue without writing it" {
  run_updater --check
  [ "$status" -eq 1 ]
  run grep -F 'old' "${DOC}"
  [ "$status" -eq 0 ]
}
