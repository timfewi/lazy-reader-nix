#!/usr/bin/env bash
set -o pipefail

# OpenRouter explain command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints concise explanation to stdout.
input="$(cat)"
model="${LAZY_READER_EXPLAIN_MODEL:-x-ai/grok-4.1-fast}"
max_tokens="1200"
temperature="0.1"

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
          content:("Explain this code in short, natural spoken language for listening. Use 4 to 6 simple sentences. No bullet points, no markdown, no code formatting, and no symbols like star dash hash slash backticks or braces. Use plain words as if a person is speaking. If context is missing, make one brief assumption and continue.\n\nCode:\n\n" + $t)
        }
      ]
    }')") || { echo "OpenRouter API request failed. Check LAZY_READER_OPENROUTER_API_KEY and network." >&2; exit 1; }

content=$(echo "$response" | jq -r '.choices[0].message.content')
if [[ -z "$content" || "$content" == "null" ]]; then
  echo "OpenRouter returned empty or null content. Response: $response" >&2
  exit 1
fi
echo "$content"
