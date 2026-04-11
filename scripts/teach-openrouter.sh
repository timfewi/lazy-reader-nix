#!/usr/bin/env bash
set -o pipefail

# OpenRouter teach command for lazy-reader (consumed via builtins.readFile)
# Reads a page of programming book text from stdin and prints an ELI5
# spoken explanation to stdout.
input="$(cat)"
model="${LAZY_READER_TEACH_MODEL:-x-ai/grok-4.1-fast}"
max_tokens="${LAZY_READER_TEACH_MAX_TOKENS:-1800}"
temperature="${LAZY_READER_TEACH_TEMPERATURE:-0.2}"

response=$(curl -sf https://openrouter.ai/api/v1/chat/completions \
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
    }')") || { echo "OpenRouter API request failed. Check LAZY_READER_OPENROUTER_API_KEY and network." >&2; exit 1; }

content=$(echo "$response" | jq -r '.choices[0].message.content')
if [[ -z "$content" || "$content" == "null" ]]; then
  echo "OpenRouter returned empty or null content. Response: $response" >&2
  exit 1
fi
echo "$content"
