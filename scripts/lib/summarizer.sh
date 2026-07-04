#!/usr/bin/env bash

run_summarizer() {
	local input_text="$1"
	local stderr_file
	stderr_file="$(mktemp)"
	local exit_code=0

	if [[ -z "$SUMMARIZE_CMD" ]]; then
		notify "No summarizer configured. Set services.lazy-reader.summarizeCommand first."
		exit 1
	fi

	local summarized_text
	summarized_text="$(printf '%s' "$input_text" | bash -c "$SUMMARIZE_CMD" 2>"$stderr_file")" || exit_code=$?

	if ((exit_code)); then
		local error_msg
		error_msg="$(<"$stderr_file")"
		rm -f "$stderr_file"
		if [[ -n "$error_msg" ]]; then
			notify "Summarize command failed (exit $exit_code): $error_msg"
		else
			notify "Summarize command failed (exit $exit_code). Check services.lazy-reader.summarizeCommand."
		fi
		exit 1
	fi
	rm -f "$stderr_file"

	if [[ -z "${summarized_text//[[:space:]]/}" ]]; then
		notify "Summarize command returned empty output."
		exit 1
	fi

	trim_text "$summarized_text" "$SUMMARIZE_MAX_CHARS"
}
