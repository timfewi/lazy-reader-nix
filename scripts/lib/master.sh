#!/usr/bin/env bash

run_master() {
	local input_text="$1"

	if [[ -z "$MASTER_CMD" ]]; then
		notify "No master summarizer configured. Set services.lazy-reader.masterCommand first."
		exit 1
	fi

	local master_text
	if ! master_text="$(printf '%s' "$input_text" | bash -c "$MASTER_CMD")"; then
		notify "Master command failed. Check services.lazy-reader.masterCommand and logs."
		exit 1
	fi

	if [[ -z "${master_text//[[:space:]]/}" ]]; then
		notify "Master command returned empty output."
		exit 1
	fi

	trim_text "$master_text" "$MASTER_MAX_CHARS"
}
