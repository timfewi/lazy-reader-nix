#!/usr/bin/env bash

run_problem_solver() {
  local input_text="$1"

  if [[ -z "$PROBLEM_SOLVER_CMD" ]]; then
    notify "No problem solver configured. Set services.lazy-reader.problemSolverCommand first."
    exit 1
  fi

  local solved_text
  if ! solved_text="$(printf '%s' "$input_text" | bash -lc "$PROBLEM_SOLVER_CMD" 2>/dev/null)"; then
    notify "Problem solver command failed. Check services.lazy-reader.problemSolverCommand."
    exit 1
  fi

  if [[ -z "${solved_text//[[:space:]]/}" ]]; then
    notify "Problem solver command returned empty output."
    exit 1
  fi

  trim_text "$solved_text" "$PROBLEM_SOLVER_MAX_CHARS"
}
