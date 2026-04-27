#!/usr/bin/env bats
# Tests for scripts/lib/selection.sh
# Covers: trim_text (pure), chunk_text_for_reading, read_selection (stubbed wl-paste)

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

setup() {
  setup_tmpdir
  # shellcheck source=scripts/lib/selection.sh
  source "${SCRIPTS_DIR}/lib/selection.sh"
}

teardown() {
  teardown_tmpdir
}

collect_chunks() {
  CHUNKS=()
  while IFS= read -r -d '' chunk; do
    CHUNKS+=("$chunk")
  done < <(chunk_text_for_reading "$1" "$2")
}

collect_reading_sections() {
  SECTION_KINDS=()
  SECTION_TEXTS=()
  while IFS= read -r -d '' kind && IFS= read -r -d '' section; do
    SECTION_KINDS+=("$kind")
    SECTION_TEXTS+=("$section")
  done < <(split_text_into_reading_sections "$1")
}

# ---------------------------------------------------------------------------
# trim_text — invariants
# ---------------------------------------------------------------------------

@test "trim_text: returns text unchanged when shorter than limit" {
  [ "$(trim_text 'hello' 10)" = "hello" ]
}

@test "trim_text: returns text unchanged when equal to limit" {
  [ "$(trim_text 'hello' 5)" = "hello" ]
}

@test "trim_text: truncates to exactly max_chars" {
  [ "$(trim_text 'hello world' 5)" = "hello" ]
}

@test "trim_text: truncates to a single character" {
  [ "$(trim_text 'abc' 1)" = "a" ]
}

@test "trim_text: handles empty input" {
  [ "$(trim_text '' 10)" = "" ]
}

@test "trim_text: invariant — output length never exceeds max_chars" {
  local input="abcdefghijklmnopqrstuvwxyz"
  for max in 0 1 5 10 26 100; do
    local result
    result="$(trim_text "$input" "$max")"
    (( ${#result} <= max ))
  done
}

# ---------------------------------------------------------------------------
# chunk_text_for_reading — chunking invariants
# ---------------------------------------------------------------------------

@test "chunk_text_for_reading: returns one chunk when text fits" {
  collect_chunks "hello world" 50
  [ "${#CHUNKS[@]}" -eq 1 ]
  [ "${CHUNKS[0]}" = "hello world" ]
}

@test "chunk_text_for_reading: prefers sentence boundaries for long text" {
  collect_chunks "First sentence. Second sentence. Third sentence." 25
  [ "${#CHUNKS[@]}" -eq 3 ]
  [ "${CHUNKS[0]}" = "First sentence." ]
  [ "${CHUNKS[1]}" = "Second sentence." ]
  [ "${CHUNKS[2]}" = "Third sentence." ]
}

@test "chunk_text_for_reading: prefers paragraph boundaries before raw truncation" {
  collect_chunks $'First paragraph.\n\nSecond paragraph.' 25
  [ "${#CHUNKS[@]}" -eq 2 ]
  [ "${CHUNKS[0]}" = "First paragraph." ]
  [ "${CHUNKS[1]}" = "Second paragraph." ]
}

@test "chunk_text_for_reading: falls back to hard splits for long words" {
  collect_chunks "supercalifragilisticexpialidocious" 10
  [ "${#CHUNKS[@]}" -eq 4 ]
  [ "${CHUNKS[0]}" = "supercalif" ]
  [ "${CHUNKS[1]}" = "ragilistic" ]
  [ "${CHUNKS[2]}" = "expialidoc" ]
  [ "${CHUNKS[3]}" = "ious" ]
}

# ---------------------------------------------------------------------------
# split_text_into_reading_sections — prose/code routing
# ---------------------------------------------------------------------------

@test "split_text_into_reading_sections: keeps prose and code blocks in order" {
  collect_reading_sections $'Intro paragraph.\n\nfunction add(a, b) {\n  return a + b;\n}\n\nAfterwards.'
  [ "${#SECTION_KINDS[@]}" -eq 3 ]
  [ "${SECTION_KINDS[0]}" = "prose" ]
  [ "${SECTION_TEXTS[0]}" = "Intro paragraph." ]
  [ "${SECTION_KINDS[1]}" = "code" ]
  [ "${SECTION_TEXTS[1]}" = $'function add(a, b) {\n  return a + b;\n}' ]
  [ "${SECTION_KINDS[2]}" = "prose" ]
  [ "${SECTION_TEXTS[2]}" = "Afterwards." ]
}

@test "split_text_into_reading_sections: keeps inline-code prose as prose" {
  collect_reading_sections "Use foo(bar) in the docs."
  [ "${#SECTION_KINDS[@]}" -eq 1 ]
  [ "${SECTION_KINDS[0]}" = "prose" ]
  [ "${SECTION_TEXTS[0]}" = "Use foo(bar) in the docs." ]
}

@test "split_text_into_reading_sections: treats shell prompt commands as code" {
  collect_reading_sections $'$ cargo new my-project\nCreated binary (application) `my-project` package'
  [ "${#SECTION_KINDS[@]}" -eq 2 ]
  [ "${SECTION_KINDS[0]}" = "code" ]
  [ "${SECTION_TEXTS[0]}" = $'$ cargo new my-project' ]
  [ "${SECTION_KINDS[1]}" = "prose" ]
  [ "${SECTION_TEXTS[1]}" = "Created binary (application) \`my-project\` package" ]
}

# ---------------------------------------------------------------------------
# read_selection / read_input_text
# ---------------------------------------------------------------------------

@test "read_selection: returns primary selection when non-empty" {
  make_stub "wl-paste" 'printf "selected text"'
  [ "$(read_selection)" = "selected text" ]
}

@test "read_selection: falls back to clipboard when primary is empty" {
  make_stub "wl-paste" '
    for arg in "$@"; do
      [[ "$arg" == "--primary" ]] && { printf ""; exit 0; }
    done
    printf "clipboard text"'
  [ "$(read_selection)" = "clipboard text" ]
}

@test "read_selection: returns empty string when wl-paste returns nothing" {
  make_stub "wl-paste" 'printf ""'
  [ "$(read_selection)" = "" ]
}

@test "read_stdin_text: returns piped stdin content" {
  run bash -c "source '${SCRIPTS_DIR}/lib/selection.sh'; read_stdin_text" <<< "stdin text"
  [ "$status" -eq 0 ]
  [ "$output" = "stdin text" ]
}

@test "read_input_text: rejects unsupported input source" {
  run bash -c "source '${SCRIPTS_DIR}/lib/selection.sh'; read_input_text invalid-source"
  [ "$status" -ne 0 ]
}
