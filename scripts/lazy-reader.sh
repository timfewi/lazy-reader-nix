#!/usr/bin/env bash
set -euo pipefail

# Source lib files relative to this script.
# When run via the Nix wrapper, ${../scripts} copies the full directory to the
# Nix store so BASH_SOURCE[0] resolves correctly in both cases.
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config.sh
source "${_DIR}/lib/config.sh"
# shellcheck source=scripts/lib/notify.sh
source "${_DIR}/lib/notify.sh"
# shellcheck source=scripts/lib/pid.sh
source "${_DIR}/lib/pid.sh"
# shellcheck source=scripts/lib/selection.sh
source "${_DIR}/lib/selection.sh"
# shellcheck source=scripts/lib/audio.sh
source "${_DIR}/lib/audio.sh"
# shellcheck source=scripts/lib/tts.sh
source "${_DIR}/lib/tts.sh"
# shellcheck source=scripts/lib/narrator.sh
source "${_DIR}/lib/narrator.sh"
# shellcheck source=scripts/lib/explainer.sh
source "${_DIR}/lib/explainer.sh"
# shellcheck source=scripts/lib/summarizer.sh
source "${_DIR}/lib/summarizer.sh"
# shellcheck source=scripts/lib/solver.sh
source "${_DIR}/lib/solver.sh"
# shellcheck source=scripts/lib/asker.sh
source "${_DIR}/lib/asker.sh"
# shellcheck source=scripts/lib/teacher.sh
source "${_DIR}/lib/teacher.sh"
# shellcheck source=scripts/lib/master.sh
source "${_DIR}/lib/master.sh"
# shellcheck source=scripts/lib/vision.sh
source "${_DIR}/lib/vision.sh"

INPUT_SOURCE="selection"
MODE="toggle"

usage() {
	printf '%s\n' "Usage: lazy-reader [--stdin|--input-source selection|stdin] [toggle|start|stop|status|narrate|explain|summarize|solve|ask|teach|master|vision]"
}

parse_args() {
	local has_mode=0
	local next_arg

	while (($#)); do
		case "$1" in
		--stdin)
			INPUT_SOURCE="stdin"
			;;
		--input-source)
			if (($# < 2)); then
				printf '%s\n' "error: --input-source requires a value" >&2
				return 1
			fi
			next_arg="$2"
			INPUT_SOURCE="$next_arg"
			shift
			;;
		--input-source=*)
			INPUT_SOURCE="${1#*=}"
			;;
		--help | -h)
			usage
			exit 0
			;;
		stop | toggle | start | status | narrate | explain | summarize | solve | ask | teach | master | vision | screenshot)
			if ((has_mode)); then
				printf '%s\n' "error: multiple commands provided" >&2
				return 1
			fi
			# "screenshot" is an alias for the vision mode.
			if [[ "$1" == "screenshot" ]]; then
				MODE="vision"
			else
				MODE="$1"
			fi
			has_mode=1
			;;
		*)
			printf '%s\n' "error: unknown argument: $1" >&2
			return 1
			;;
		esac
		shift
	done

	case "$INPUT_SOURCE" in
	selection | stdin | clipboard)
		;;
	*)
		printf '%s\n' "error: unsupported input source: $INPUT_SOURCE" >&2
		return 1
		;;
	esac
}

missing_input_message() {
	local selection_message="$1"

	if [[ "$INPUT_SOURCE" == "stdin" ]]; then
		printf '%s\n' "No stdin text found. Pipe text to lazy-reader."
		return 0
	fi

	printf '%s\n' "$selection_message"
}

require_input_text() {
	local selection_message="$1"
	local max_chars="${2:-}"
	local input_source="${3:-${INPUT_SOURCE:-selection}}"
	local text

	if ! text="$(read_input_text "$input_source")"; then
		notify "$(missing_input_message "$selection_message")"
		exit 1
	fi

	if [[ -z "${text//[[:space:]]/}" ]]; then
		notify "$(missing_input_message "$selection_message")"
		exit 1
	fi

	if [[ -n "$max_chars" ]]; then
		text="$(trim_text "$text" "$max_chars")"
	fi

	printf '%s' "$text"
}

start_reading() {
	validate_config

	local text
	local section_index=0
	local section_kind
	local section_text
	text="$(require_input_text "No selected text found. Highlight text and press Super+S.")"

	while IFS= read -r -d '' section_kind && IFS= read -r -d '' section_text; do
		if ((section_index == 0)); then
			speak_reading_section "$section_kind" "$section_text" "Reading selected text..."
		else
			speak_reading_section "$section_kind" "$section_text" ""
		fi
		((section_index += 1))
	done < <(split_text_into_reading_sections "$text")
}

speak_generated_text() {
	local text="$1"
	local started_message="$2"

	# Send all text in a single TTS call — OpenRouter handles arbitrary length.
	speak_text "$text" "$started_message"
}

speak_reading_section() {
	local section_kind="$1"
	local section_text="$2"
	local started_message="$3"

	if [[ "$section_kind" == "code" ]]; then
		if [[ -n "$EXPLAIN_CMD" ]]; then
			section_text="$(trim_text "$section_text" "$MAX_CHARS")"
			speak_generated_text "$(run_explainer "$section_text")" "$started_message"
			return 0
		fi

		if [[ -n "$NARRATE_CMD" ]]; then
			section_text="$(trim_text "$section_text" "$NARRATE_INPUT_MAX_CHARS")"
			speak_generated_text "$(run_narrator "$section_text")" "$started_message"
			return 0
		fi
	fi

	# prose — send full section in a single TTS call
	speak_text "$section_text" "$started_message"
}

narrate_selection() {
	validate_config

	local text
	text="$(require_input_text "No selected text found. Highlight a passage and press your narrate shortcut." "$NARRATE_INPUT_MAX_CHARS")"

	local narrated_text
	narrated_text="$(run_narrator "$text")"

	speak_generated_text "$narrated_text" "Reading narration..."
}

explain_selection() {
	validate_config

	local text
	text="$(require_input_text "No selected text found. Highlight a snippet and press your explain shortcut." "$MAX_CHARS")"

	local explained_text
	explained_text="$(run_explainer "$text")"

	speak_generated_text "$explained_text" "Reading explanation..."
}

summarize_selection() {
	validate_config

	local text
	text="$(require_input_text "No selected text found. Highlight a passage and press your summarize shortcut." "$SUMMARIZE_INPUT_MAX_CHARS")"

	local summarized_text
	summarized_text="$(run_summarizer "$text")"

	speak_generated_text "$summarized_text" "Reading summary..."
}

solve_selection() {
	validate_config

	local text
	text="$(require_input_text "No selected text found. Highlight a snippet and press your solve shortcut." "$MAX_CHARS")"

	local solved_text
	solved_text="$(run_problem_solver "$text")"

	speak_generated_text "$solved_text" "Reading solution..."
}

ask_selection() {
	validate_config

	local text
	text="$(require_input_text "No selected text found. Highlight a snippet and press your ask shortcut." "$MAX_CHARS")"

	local answered_text
	local answer_file
	local ask_status
	answer_file="$(mktemp)"
	if run_asker "$text" >"$answer_file"; then
		answered_text="$(cat "$answer_file")"
	else
		ask_status=$?
		rm -f "$answer_file"
		if [[ "$ask_status" -eq 2 ]]; then
			exit 0
		fi
		exit "$ask_status"
	fi
	rm -f "$answer_file"

	if [[ -z "${answered_text//[[:space:]]/}" ]]; then
		exit 0
	fi

	speak_generated_text "$answered_text" "Reading answer..."
}

teach_selection() {
	validate_config

	local text
	text="$(require_input_text "No selected text found. Highlight a passage and press your teach shortcut." "$TEACH_INPUT_MAX_CHARS")"

	local taught_text
	taught_text="$(run_teacher "$text")"

	speak_generated_text "$taught_text" "Reading explanation..."
}

master_selection() {
	validate_config

	notify "Reading clipboard for expert summarization..."

	local text
	text="$(require_input_text "No text in clipboard. Copy text first, then press Super+M." "$MASTER_INPUT_MAX_CHARS" "clipboard")"

	local clip_len
	clip_len="$(printf '%s' "$text" | wc -c)"
	if ! zenity --question --title="Lazy Reader Master" \
		--text="Send ${clip_len} characters from clipboard to OpenRouter for expert summarization?\n\nWARNING: Do not send passwords, API keys, or sensitive personal data." \
		--ok-label="Send" --cancel-label="Cancel" 2>/dev/null; then
		notify "Master summarization cancelled."
		exit 0
	fi

	local master_text
	master_text="$(run_master "$text")"

	speak_generated_text "$master_text" "Master summary..."
}

vision_selection() {
	validate_config

	if [[ -z "$VISION_CMD" ]]; then
		notify "No vision command configured. Set services.lazy-reader.visionCommand first."
		exit 1
	fi

	local mime
	if ! mime="$(detect_clipboard_image_mime)"; then
		notify "No image in clipboard. Take a screenshot to the clipboard first, then press Super+I."
		exit 1
	fi

	if ! zenity --question --title="Lazy Reader Screenshot" \
		--text="Send the clipboard screenshot to OpenRouter to read aloud?\n\nWARNING: Do not send images containing passwords, API keys, or sensitive personal data." \
		--ok-label="Send" --cancel-label="Cancel" 2>/dev/null; then
		notify "Screenshot reading cancelled."
		exit 0
	fi

	notify "Reading screenshot..."

	# Pipe the raw clipboard image straight into the vision command. The binary
	# bytes flow through the pipe into run_vision's stdin; only the textual model
	# output is captured here.
	local vision_text
	export LAZY_READER_VISION_MIME="$mime"
	vision_text="$(wl-paste --type "$mime" 2>/dev/null | run_vision)"

	speak_generated_text "$vision_text" "Reading screenshot..."
}

main() {
	mkdir -p "$RUNTIME_DIR"
	cleanup_stale_pid_file

	if ! parse_args "$@"; then
		notify "$(usage)"
		exit 1
	fi

	case "$MODE" in
	stop)
		stop_running_reader
		exit 0
		;;
	toggle)
		if is_running; then
			stop_running_reader
			exit 0
		fi
		;;
	start)
		if is_running; then
			notify "Already reading. Press Super+S again to stop."
			exit 0
		fi
		;;
	status)
		if is_running; then
			echo "reading"
		else
			echo "idle"
		fi
		exit 0
		;;
	explain | summarize | narrate | solve | ask | teach | master | vision)
		if is_running; then
			stop_running_reader
			exit 0
		fi
		;;
	*)
		notify "$(usage)"
		exit 1
		;;
	esac

	# Atomic PID file claim — prevents two readers starting simultaneously (TOCTOU race).
	if ! (
		set -o noclobber
		echo "$$" >"$PID_FILE"
	) 2>/dev/null; then
		if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
			notify "Already reading. Press shortcut to stop."
			exit 0
		fi
		# Stale PID from dead process — atomic overwrite (prevents second claimer).
		if ! (
			set -o noclobber
			echo "$$" >"$PID_FILE"
		) 2>/dev/null; then
			notify "Already reading. Press shortcut to stop."
			exit 0
		fi
	fi
	OWNS_PID_FILE="1"
	trap cleanup EXIT INT TERM

	case "$MODE" in
	narrate) narrate_selection ;;
	explain) explain_selection ;;
	summarize) summarize_selection ;;
	solve) solve_selection ;;
	ask) ask_selection ;;
	teach) teach_selection ;;
	master) master_selection ;;
	vision) vision_selection ;;
	*) start_reading ;;
	esac
}

main "$@"
