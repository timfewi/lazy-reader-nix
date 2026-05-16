#!/usr/bin/env bash

validate_config() {
	load_tts_config
	if ! [[ "$SPEED" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v speed="$SPEED" 'BEGIN { exit !(speed > 0) }'; then

		notify "Invalid speed '$SPEED'. Use a positive number like 1.0, 1.3, or 1.4."
		exit 1
	fi

	if ! [[ "$PLAYBACK_SPEED" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v speed="$PLAYBACK_SPEED" 'BEGIN { exit !(speed > 0) }'; then
		notify "Invalid playback speed '$PLAYBACK_SPEED'. Use a positive number like 1.0, 1.3, or 1.4."
		exit 1
	fi

	if ! [[ "$GENERATED_SPEECH_CHUNK_MAX_CHARS" =~ ^[0-9]+$ ]] || ((GENERATED_SPEECH_CHUNK_MAX_CHARS <= 0)); then
		notify "Invalid generated speech chunk max chars '$GENERATED_SPEECH_CHUNK_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$SPEAKER" =~ ^[0-9]+$ ]]; then
		notify "Invalid speaker '$SPEAKER'. Use a non-negative integer."
		exit 1
	fi

	if ! [[ "$MAX_CHARS" =~ ^[0-9]+$ ]] || ((MAX_CHARS <= 0)); then
		notify "Invalid max chars '$MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$NARRATE_MAX_CHARS" =~ ^[0-9]+$ ]] || ((NARRATE_MAX_CHARS <= 0)); then
		notify "Invalid narrate max chars '$NARRATE_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$NARRATE_INPUT_MAX_CHARS" =~ ^[0-9]+$ ]] || ((NARRATE_INPUT_MAX_CHARS <= 0)); then
		notify "Invalid narrate input max chars '$NARRATE_INPUT_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$EXPLAIN_MAX_CHARS" =~ ^[0-9]+$ ]] || ((EXPLAIN_MAX_CHARS <= 0)); then
		notify "Invalid explain max chars '$EXPLAIN_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$SUMMARIZE_MAX_CHARS" =~ ^[0-9]+$ ]] || ((SUMMARIZE_MAX_CHARS <= 0)); then
		notify "Invalid summarize max chars '$SUMMARIZE_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$SUMMARIZE_INPUT_MAX_CHARS" =~ ^[0-9]+$ ]] || ((SUMMARIZE_INPUT_MAX_CHARS <= 0)); then
		notify "Invalid summarize input max chars '$SUMMARIZE_INPUT_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$PROBLEM_SOLVER_MAX_CHARS" =~ ^[0-9]+$ ]] || ((PROBLEM_SOLVER_MAX_CHARS <= 0)); then
		notify "Invalid problem solver max chars '$PROBLEM_SOLVER_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if ! [[ "$ASK_MAX_CHARS" =~ ^[0-9]+$ ]] || ((ASK_MAX_CHARS <= 0)); then
		notify "Invalid ask max chars '$ASK_MAX_CHARS'. Use a positive integer."
		exit 1
	fi

	if [[ "${TTS_PROVIDER:-piper}" == "piper" ]]; then
		if [[ ! -f "$MODEL" ]]; then
			notify "Piper model not found at '$MODEL'. Set services.lazy-reader.model to a valid .onnx file path."
			exit 1
		fi

		if [[ -n "$MODEL_CONFIG" ]] && [[ ! -f "$MODEL_CONFIG" ]]; then
			notify "Piper model config not found at '$MODEL_CONFIG'."
			exit 1
		fi
	fi
}

load_tts_config() {
	TTS_PROVIDER="${LAZY_READER_TTS_PROVIDER:-piper}"
	TTS_MODEL="${LAZY_READER_TTS_MODEL:-tts-1}"
	TTS_VOICE="${LAZY_READER_TTS_VOICE:-alloy}"

	local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/lazy-reader/tts.conf"
	if [[ -f "$config_file" ]]; then
		local line key value
		while IFS= read -r line || [[ -n "$line" ]]; do
			[[ -z "$line" || "$line" == \#* ]] && continue
			key="${line%%=*}"
			value="${line#*=}"
			case "$key" in
				TTS_PROVIDER)
					TTS_PROVIDER="$value"
					;;
				TTS_MODEL)
					TTS_MODEL="$value"
					;;
				TTS_VOICE)
					TTS_VOICE="$value"
					;;
			esac
		done < "$config_file"
	fi

	case "$TTS_PROVIDER" in
		piper|openrouter)
			;;
		*)
			notify "Invalid TTS provider '$TTS_PROVIDER'. Use 'piper' or 'openrouter'."
			exit 1
			;;
	esac
}

speak_text() {
	local text="$1"
	local started_message="$2"

	load_tts_config

	if [[ "${TTS_PROVIDER:-piper}" == "openrouter" ]]; then
		_speak_openrouter "$text" "$started_message"
	else
		_speak_piper "$text" "$started_message"
	fi
}

_speak_piper() {
	local text="$1"
	local started_message="$2"

	local length_scale
	length_scale="$(awk -v speed="$SPEED" 'BEGIN { printf "%.6f", 1.0 / speed }')"

	# piper-tts auto-detects config as "${model}.json" and ignores -c.
	# Bundle model + config into a temp dir so auto-detection finds both.
	local model_path="$MODEL"
	if [[ -n "$MODEL_CONFIG" ]]; then
		MODEL_DIR="$(mktemp -d)"
		ln -sf "$MODEL" "$MODEL_DIR/model.onnx"
		ln -sf "$MODEL_CONFIG" "$MODEL_DIR/model.onnx.json"
		model_path="$MODEL_DIR/model.onnx"
	fi

	local -a piper_cmd
	piper_cmd=(piper -m "$model_path" -s "$SPEAKER" --length-scale "$length_scale")

	if [[ -n "$PIPER_DATA_DIR" ]]; then
		piper_cmd+=(--data-dir "$PIPER_DATA_DIR")
	fi

	if [[ -n "$started_message" ]]; then
		notify "$started_message"
	fi

	if [[ "$STREAM_PLAYBACK" == "1" ]]; then
		if ! printf '%s' "$text" | "${piper_cmd[@]}" -f - 2>/dev/null | play_audio_stream >/dev/null 2>&1; then
			notify "Streaming playback failed. Falling back to file playback."
		else
			return 0
		fi
	fi

	RESPONSE_FILE="$(mktemp --suffix=".wav")"

	if ! printf '%s' "$text" | "${piper_cmd[@]}" -f "$RESPONSE_FILE" >/dev/null 2>&1; then
		notify "Local Piper synthesis failed. Check model path, model config, and speaker ID."
		exit 1
	fi

	if ! play_audio "$RESPONSE_FILE"; then
		notify "Audio playback failed with player '$PLAYER'."
		exit 1
	fi
}

_speak_openrouter() {
	local text="$1"
	local started_message="$2"

	if [[ -n "$started_message" ]]; then
		notify "$started_message"
	fi

	local api_key
	if [[ -n "${LAZY_READER_OPENROUTER_API_KEY_FILE:-}" && -f "$LAZY_READER_OPENROUTER_API_KEY_FILE" ]]; then
		api_key="$(cat "$LAZY_READER_OPENROUTER_API_KEY_FILE")"
	else
		api_key="${LAZY_READER_OPENROUTER_API_KEY:-}"
	fi

	if [[ -z "$api_key" ]]; then
		notify "OpenRouter API key not found. Set LAZY_READER_OPENROUTER_API_KEY or configure LAZY_READER_OPENROUTER_API_KEY_FILE."
		exit 1
	fi

	local tts_model="${TTS_MODEL:-tts-1}"
	local tts_voice="${TTS_VOICE:-alloy}"
	local payload
	payload="$(jq -n \
		--arg model "$tts_model" \
		--arg input "$text" \
		--arg voice "$tts_voice" \
		'{model: $model, input: $input, voice: $voice, response_format: "mp3"}')"

	local response_file
	response_file="$(mktemp --suffix=".mp3")"

	if ! curl --fail --silent --show-error https://openrouter.ai/api/v1/audio/speech \
		-H "Authorization: Bearer $api_key" \
		-H "Content-Type: application/json" \
		-d "$payload" \
		-o "$response_file"; then
		notify "OpenRouter TTS request failed."
		exit 1
	fi

	if ! play_audio "$response_file"; then
		notify "Audio playback failed with player '$PLAYER'."
		exit 1
	fi
}
