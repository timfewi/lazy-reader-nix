#!/usr/bin/env bash
set -o pipefail

# OpenRouter summarize command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints a concise spoken summary to stdout.
input="$(cat)"
model="${LAZY_READER_SUMMARIZE_MODEL:-openai/gpt-oss-safeguard-20b}"
max_tokens="${LAZY_READER_SUMMARIZE_MAX_TOKENS:-32000}"
temperature="${LAZY_READER_SUMMARIZE_TEMPERATURE:-0.12}"

response=$(curl -sS --max-time 120 --connect-timeout 15 \
	https://openrouter.ai/api/v1/chat/completions \
	-H "Authorization: Bearer $LAZY_READER_OPENROUTER_API_KEY" \
	-H "Content-Type: application/json" \
	-d "$(jq -n \
		--arg t "$input" \
		--arg m "$model" \
		--argjson tok "$max_tokens" \
		--argjson temp "$temperature" \
		'{
      model:$m,
      temperature:$temp,
      max_tokens:$tok,
      messages:[
        {
          role:"user",
          content:("Summarize the following passage for listening aloud. Compress it into a clear spoken summary that keeps the main point, the most important supporting details, and any conclusion or next step. Prefer short paragraphs or a smooth spoken flow rather than a list. Do not use markdown, bullet points, headings, or code formatting. Avoid reading symbols aloud unless absolutely necessary. If the passage is technical, translate it into plain language while preserving the key meaning. Keep the summary concise but complete enough that someone could understand the passage without hearing every original detail. Respond in the same language as the passage.\n\nPassage:\n\n" + $t)
        }
      ]
    }')") || {
	exit_code=$?
	if [[ $exit_code -eq 28 ]]; then
		echo "OpenRouter request timed out after 120 seconds. Text may be too long." >&2
	else
		echo "OpenRouter API request failed (curl exit code $exit_code). Check network." >&2
	fi
	exit 1
}

# Check for OpenRouter error response
err_msg=$(echo "$response" | jq -r '.error.message // empty')
if [[ -n "$err_msg" ]]; then
	err_code=$(echo "$response" | jq -r '.error.code // 0')
	echo "OpenRouter error ($err_code): $err_msg" >&2
	if [[ "$err_code" == "429" ]]; then
		echo "Rate limited. Consider a different model or wait." >&2
	fi
	exit 1
fi

content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
if [[ -z "$content" ]]; then
	echo "OpenRouter returned empty response. Raw: $(echo "$response" | head -c 500)" >&2
	exit 1
fi
echo "$content"
