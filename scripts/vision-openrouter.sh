#!/usr/bin/env bash
set -o pipefail

# OpenRouter vision command for lazy-reader (consumed via builtins.readFile).
# Reads raw image bytes (e.g. a clipboard screenshot) from stdin and prints a
# spoken-style reading of the image to stdout. "Smart auto" behavior: if the
# image is mostly text it transcribes/reads it cleanly; if it is a diagram, UI,
# chart, or photo it describes what is shown.

model="${LAZY_READER_VISION_MODEL:-google/gemini-2.0-flash-001}"
max_tokens="${LAZY_READER_VISION_MAX_TOKENS:-16000}"
temperature="${LAZY_READER_VISION_TEMPERATURE:-0.2}"
mime="${LAZY_READER_VISION_MIME:-image/png}"

api_key="${LAZY_READER_OPENROUTER_API_KEY:-}"
if [[ -z "$api_key" ]]; then
	echo "OpenRouter API key not set. Check LAZY_READER_OPENROUTER_API_KEY_FILE or environment." >&2
	exit 1
fi

# Work in a private temp dir. Image base64 and the request payload can be many
# megabytes, so they must go through files, never command-line args (MAX_ARG_STRLEN)
# nor shell variables passed as a single curl/jq argument.
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
b64file="$workdir/image.b64"
payloadfile="$workdir/payload.json"
hdrfile="$workdir/headers.txt"

base64 -w0 >"$b64file"
if [[ ! -s "$b64file" ]]; then
	echo "No image data received on stdin. Copy a screenshot to the clipboard first." >&2
	exit 1
fi

printf 'Authorization: Bearer %s\n' "$api_key" >"$hdrfile"
chmod 600 "$hdrfile"

prompt="You are reading a screenshot aloud for someone who cannot see it. First decide what the image mainly is. If it is mostly text, such as an article, documentation, an error message, a chat, or code, then read and transcribe that text cleanly and in full, smoothing only enough to make it listenable, and keep important identifiers, numbers, and exact values intact. If it is mainly a diagram, a user interface, a chart, or a photo, then describe clearly what is shown and what it conveys. If it contains both, read the meaningful text and briefly describe the surrounding visual context. Speak in calm, natural spoken language as if a person is talking. Do not use markdown, bullet points, headings, code formatting, or any symbols like star, dash, hash, slash, backtick, or brace. Do not invent text that is not visible. If the image is unreadable or blank, say so in one sentence."

jq -n \
	--arg m "$model" \
	--argjson tok "$max_tokens" \
	--argjson temp "$temperature" \
	--arg p "$prompt" \
	--arg mime "$mime" \
	--rawfile img "$b64file" \
	'{
    model: $m,
    temperature: $temp,
    max_tokens: $tok,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: $p },
          { type: "image_url", image_url: { url: ("data:" + $mime + ";base64," + ($img | gsub("\n"; ""))) } }
        ]
      }
    ]
  }' >"$payloadfile"

response=$(curl -sS --max-time 180 --connect-timeout 15 \
	https://openrouter.ai/api/v1/chat/completions \
	-H "@$hdrfile" \
	-H "Content-Type: application/json" \
	-d "@$payloadfile") || {
	exit_code=$?
	if [[ $exit_code -eq 28 ]]; then
		echo "OpenRouter request timed out after 180 seconds. The image may be too large." >&2
	else
		echo "OpenRouter API request failed (curl exit code $exit_code). Check network." >&2
	fi
	exit 1
}

err_msg=$(echo "$response" | jq -r '.error.message // empty')
if [[ -n "$err_msg" ]]; then
	err_code=$(echo "$response" | jq -r '.error.code // 0')
	echo "OpenRouter error ($err_code): $err_msg" >&2
	if [[ "$err_code" == "429" ]]; then
		echo "Rate limited. Try a different LAZY_READER_VISION_MODEL or wait." >&2
	fi
	exit 1
fi

content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
if [[ -z "$content" ]]; then
	echo "OpenRouter returned empty response. The model may not support image input. Raw: $(echo "$response" | head -c 500)" >&2
	exit 1
fi

echo "$content"
