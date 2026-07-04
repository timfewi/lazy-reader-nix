#!/usr/bin/env bash

run_teacher() {
	local input_text="$1"
	local stderr_file
	stderr_file="$(mktemp)"
	local exit_code=0

	if [[ -z "$TEACH_CMD" ]]; then
		notify "No teach command configured. Set services.lazy-reader.teachCommand first."
		exit 1
	fi

	local taught_text
	taught_text="$(printf '%s' "$input_text" | bash -c "$TEACH_CMD" 2>"$stderr_file")" || exit_code=$?

	if ((exit_code)); then
		local error_msg
		error_msg="$(<"$stderr_file")"
		rm -f "$stderr_file"
		if [[ -n "$error_msg" ]]; then
			notify "Teach command failed (exit $exit_code): $error_msg"
		else
			notify "Teach command failed (exit $exit_code). Check services.lazy-reader.teachCommand."
		fi
		exit 1
	fi
	rm -f "$stderr_file"

	if [[ -z "${taught_text//[[:space:]]/}" ]]; then
		notify "Teach command returned empty output."
		exit 1
	fi

	trim_text "$taught_text" "$TEACH_MAX_CHARS"
}
