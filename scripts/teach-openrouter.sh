#!/usr/bin/env bash
set -o pipefail

# OpenRouter teach command for lazy-reader (consumed via builtins.readFile)
# Reads a page of programming book text from stdin and prints an ELI5
# spoken explanation to stdout.
input="$(cat)"
model="${LAZY_READER_TEACH_MODEL:-openai/gpt-oss-safeguard-20b}"
max_tokens="${LAZY_READER_TEACH_MAX_TOKENS:-18000}"
temperature="${LAZY_READER_TEACH_TEMPERATURE:-0.2}"

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
          content:("You are helping someone understand a page from a programming book. Explain it clearly and simply, as if the listener is reasonably smart but completely new to this specific topic. Use plain short sentences and include a helpful analogy if it makes the concept clearer. Cover these four things in a natural flowing way: what this concept is, why it matters in practice, how it works in simple terms, and the one thing the listener should remember. Do not use markdown, bullet points, headings, code formatting, or any symbols. Speak naturally as if talking to a friend.\n\nPage:\n\n" + $t)
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
