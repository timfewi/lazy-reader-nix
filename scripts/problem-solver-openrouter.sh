#!/usr/bin/env bash
set -o pipefail

# OpenRouter problem-solver command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints a concise, practical answer to stdout.
input="$(cat)"
model="${LAZY_READER_PROBLEM_SOLVER_MODEL:-openai/gpt-oss-safeguard-20b}"
max_tokens="${LAZY_READER_PROBLEM_SOLVER_MAX_TOKENS:-16000}"
temperature="${LAZY_READER_PROBLEM_SOLVER_TEMPERATURE:-0.12}"

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
          content:("You are a senior troubleshooting assistant. The user will provide selected text that may include terminal output, compiler errors, logs, stack traces, or code snippets. Explain the problem in natural spoken language as if helping a teammate. Do not read symbols, punctuation, or code characters out loud unless absolutely necessary. Do not repeat raw error text. Start with the most likely cause in one short sentence. Then describe what to do next using clear spoken transitions like First, Next, Then, and Finally. Give practical, concrete steps, including exact commands or file names only when useful. Keep each step short and easy to follow. If there are multiple possible causes, pick the most likely one and include one quick check to confirm it. End with what success should look like and one fallback action if it still fails. Avoid markdown, bullet lists, headings, and code fences. Keep the response concise, calm, and human.\n\nSelected text:\n\n" + $t)
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
