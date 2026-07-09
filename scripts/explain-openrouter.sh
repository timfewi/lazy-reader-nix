#!/usr/bin/env bash
set -o pipefail

# OpenRouter explain command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints concise explanation to stdout.
input="$(cat)"
model="${LAZY_READER_EXPLAIN_MODEL:-openai/gpt-4o-mini}"
max_tokens="${LAZY_READER_EXPLAIN_MAX_TOKENS:-12000}"
temperature="${LAZY_READER_EXPLAIN_TEMPERATURE:-0.1}"

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
          content:("Explain this code in short, natural spoken language for listening. Use 4 to 6 simple sentences. No bullet points, no markdown, no code formatting, and no symbols like star dash hash slash backticks or braces. Use plain words as if a person is speaking. If context is missing, make one brief assumption and continue.\n\nCode:\n\n" + $t)
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
