#!/usr/bin/env bash

run_problem_solver() {
	local input_text="$1"
	local stderr_file
	stderr_file="$(mktemp)"
	local exit_code=0

	if [[ -z "$PROBLEM_SOLVER_CMD" ]]; then
		notify "No problem solver configured. Set services.lazy-reader.problemSolverCommand first."
		exit 1
	fi

	local solved_text
	solved_text="$(printf '%s' "$input_text" | bash -c "$PROBLEM_SOLVER_CMD" 2>"$stderr_file")" || exit_code=$?

	if ((exit_code)); then
		local error_msg
		error_msg="$(<"$stderr_file")"
		rm -f "$stderr_file"
		if [[ -n "$error_msg" ]]; then
			notify "Problem solver command failed (exit $exit_code): $error_msg"
		else
			notify "Problem solver command failed (exit $exit_code). Check services.lazy-reader.problemSolverCommand."
		fi
		exit 1
	fi
	rm -f "$stderr_file"

	if [[ -z "${solved_text//[[:space:]]/}" ]]; then
		notify "Problem solver command returned empty output."
		exit 1
	fi

	trim_text "$solved_text" "$PROBLEM_SOLVER_MAX_CHARS"
}
