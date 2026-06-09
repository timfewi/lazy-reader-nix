#!/usr/bin/env bash

run_narrator() {
	local input_text="$1"
	local stderr_file
	stderr_file="$(mktemp)"
	local exit_code=0

	if [[ -z "$NARRATE_CMD" ]]; then
		notify "No narrate command configured. Set LAZY_READER_NARRATE_CMD first."
		exit 1
	fi

	local narrated_text
	narrated_text="$(printf '%s' "$input_text" | bash -c "$NARRATE_CMD" 2>"$stderr_file")" || exit_code=$?

	if ((exit_code)); then
		local error_msg
		error_msg="$(<"$stderr_file")"
		rm -f "$stderr_file"
		if [[ -n "$error_msg" ]]; then
			notify "Narrate command failed (exit $exit_code): $error_msg"
		else
			notify "Narrate command failed (exit $exit_code). Check LAZY_READER_NARRATE_CMD."
		fi
		exit 1
	fi
	rm -f "$stderr_file"

	if [[ -z "${narrated_text//[[:space:]]/}" ]]; then
		notify "Narrate command returned empty output."
		exit 1
	fi

	trim_text "$narrated_text" "$NARRATE_MAX_CHARS"
}
