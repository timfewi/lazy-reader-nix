#!/usr/bin/env bash

# run_vision reads raw image bytes on its own stdin (a clipboard screenshot) and
# pipes them straight into VISION_CMD. The binary image is never captured into a
# shell variable — only the textual model output is — so null bytes and trailing
# bytes are preserved on the way to the backend.
run_vision() {
	if [[ -z "$VISION_CMD" ]]; then
		notify "No vision command configured. Set services.lazy-reader.visionCommand first."
		exit 1
	fi

	local stderr_file
	stderr_file="$(mktemp)"
	local exit_code=0

	local vision_text
	vision_text="$(bash -c "$VISION_CMD" 2>"$stderr_file")" || exit_code=$?

	if ((exit_code)); then
		local error_msg
		error_msg="$(<"$stderr_file")"
		rm -f "$stderr_file"
		if [[ -n "$error_msg" ]]; then
			notify "Vision command failed (exit $exit_code): $error_msg"
		else
			notify "Vision command failed (exit $exit_code). Check services.lazy-reader.visionCommand."
		fi
		exit 1
	fi
	rm -f "$stderr_file"

	if [[ -z "${vision_text//[[:space:]]/}" ]]; then
		notify "Vision command returned empty output."
		exit 1
	fi

	trim_text "$vision_text" "$VISION_MAX_CHARS"
}
