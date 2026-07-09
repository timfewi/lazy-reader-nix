# Shared test helpers. Load with: load '../helpers/common'
#
# Provides:
#   setup_tmpdir    — isolated temp dir, sets XDG_RUNTIME_DIR + STUB_DIR + updates PATH
#   teardown_tmpdir — removes TEST_TMPDIR
#   make_stub NAME [BODY] — create a fake executable in $STUB_DIR
#   make_model_file — touch a fake .onnx and echo its path

setup_tmpdir() {
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"
  export XDG_CONFIG_HOME="${TEST_TMPDIR}/config"
  mkdir -p "$XDG_CONFIG_HOME"
  export XDG_RUNTIME_DIR="${TEST_TMPDIR}/runtime"
  mkdir -p "$XDG_RUNTIME_DIR"
  export STUB_DIR="${TEST_TMPDIR}/stubs"
  mkdir -p "$STUB_DIR"
  export PATH="${STUB_DIR}:${PATH}"
}

teardown_tmpdir() {
  [[ -n "${TEST_TMPDIR:-}" ]] && rm -rf "$TEST_TMPDIR"
}

# make_stub NAME [BODY]  — body defaults to `exit 0`
make_stub() {
  local name="$1"
  local body="${2:-exit 0}"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "${STUB_DIR}/${name}"
  chmod +x "${STUB_DIR}/${name}"
}

# make_openrouter_jq_stub CONTENT — stub `jq` for the *-openrouter.sh helpers.
#
# Those scripts call jq four ways: once with -n to build the request payload,
# then three times to read `.error.message`, `.error.code` and the response
# content. A stub that answers every call with CONTENT makes the script read a
# summary as an error message and bail out, so dispatch on the filter instead.
# The -n invocation is appended to $LAZY_READER_TEST_JQ_LOG.
make_openrouter_jq_stub() {
  local content="$1"
  make_stub "jq" '
    if [[ "${1:-}" == "-n" ]]; then
      printf "%s\n" "$@" >> "$LAZY_READER_TEST_JQ_LOG"
      printf "{\"payload\":true}"
      exit 0
    fi

    filter="${!#}"
    cat >/dev/null
    case "$filter" in
      *.error.message*) printf "" ;;
      *.error.code*) printf "0" ;;
      *) printf "%s" '"$(printf '%q' "$content")"' ;;
    esac
  '
}

# Create a zero-byte fake .onnx model file and print its path.
make_model_file() {
  local path="${TEST_TMPDIR}/fake-model.onnx"
  touch "$path"
  printf '%s' "$path"
}
