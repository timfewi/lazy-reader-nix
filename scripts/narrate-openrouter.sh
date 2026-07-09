#!/usr/bin/env bash
set -o pipefail

# OpenRouter narrate command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints a faithful spoken rendering to stdout.
input="$(cat)"
model="${LAZY_READER_NARRATE_MODEL:-openai/gpt-oss-safeguard-20b}"
max_tokens="${LAZY_READER_NARRATE_MAX_TOKENS:-32000}"
temperature="${LAZY_READER_NARRATE_TEMPERATURE:-0.12}"

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
          content:("You are a faithful spoken renderer of technical documentation and source code. Rewrite the selected text for listening aloud without adding information that is not explicitly present in the text. Do not invent behavior, examples, missing context, or background knowledge about the language, library, tool, or framework. For prose, keep the wording close to the original while smoothing formatting into natural spoken sentences. For code, config, shell commands, logs, or mixed technical text, describe only what is visible in the selected text and preserve every identifier, function name, option name, flag, exact value, file path, and command in the order they appear. Do not drop, merge, or paraphrase those tokens. Never read any type of brackets, braces, parentheses, angle brackets, or square brackets aloud. Omit low-value punctuation, indentation noise, markdown markers, and code fences unless saying them is required to avoid changing the meaning. For mixed prose and code, handle each segment in order without reordering or combining them. If the text describes steps, preserve their sequence using short spoken transitions like first, then, next, and finally. If something is unclear from the selected text alone, say only what is explicitly visible instead of guessing. Keep the tone calm, precise, concise, source-faithful, and ready to be read aloud. No bullet points, markdown, headings, or code fences. Respond in the same language as the selected text, but keep every identifier, function name, option name, flag, exact value, file path, and command verbatim in its original form.\n\nSelected text:\n\n" + $t)
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
