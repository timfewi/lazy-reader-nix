#!/usr/bin/env bash

run_explainer() {
	local input_text="$1"
	local stderr_file
	stderr_file="$(mktemp)"
	local exit_code=0

	if [[ -z "$EXPLAIN_CMD" ]]; then
		notify "No explainer configured. Set services.lazy-reader.explainCommand first."
		exit 1
	fi

	local explained_text
	explained_text="$(printf '%s' "$input_text" | bash -c "$EXPLAIN_CMD" 2>"$stderr_file")" || exit_code=$?

	if ((exit_code)); then
		local error_msg
		error_msg="$(<"$stderr_file")"
		rm -f "$stderr_file"
		if [[ -n "$error_msg" ]]; then
			notify "Explain command failed (exit $exit_code): $error_msg"
		else
			notify "Explain command failed (exit $exit_code). Check services.lazy-reader.explainCommand."
		fi
		exit 1
	fi
	rm -f "$stderr_file"

	if [[ -z "${explained_text//[[:space:]]/}" ]]; then
		notify "Explain command returned empty output."
		exit 1
	fi

	trim_text "$explained_text" "$EXPLAIN_MAX_CHARS"
}
