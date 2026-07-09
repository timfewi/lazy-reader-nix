#!/usr/bin/env bats
# Tests for the language contract shared by every scripts/*-openrouter.sh prompt.
# Covers: each mode mirrors the source language, and no mode re-pins English.

load '../helpers/common'

SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../../scripts"

MODES=(narrate explain summarize problem-solver ask teach master vision)

@test "every openrouter prompt asks for the source language" {
  for mode in "${MODES[@]}"; do
    run grep -qF 'same language' "${SCRIPTS_DIR}/${mode}-openrouter.sh"
    [ "$status" -eq 0 ] || {
      echo "${mode}-openrouter.sh does not instruct the model to mirror the source language"
      return 1
    }
  done
}

@test "no openrouter prompt pins the answer to English" {
  for mode in "${MODES[@]}"; do
    run grep -qF 'plain English' "${SCRIPTS_DIR}/${mode}-openrouter.sh"
    [ "$status" -ne 0 ] || {
      echo "${mode}-openrouter.sh forces English output"
      return 1
    }
  done
}
