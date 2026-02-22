#!/usr/bin/env bash

# OpenRouter explain command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints concise explanation to stdout.
input="$(cat)"
model="${LAZY_READER_EXPLAIN_MODEL:-openai/gpt-4o-mini}"
max_tokens="${LAZY_READER_EXPLAIN_MAX_TOKENS:-120}"
temperature="${LAZY_READER_EXPLAIN_TEMPERATURE:-0.1}"

curl -sf https://openrouter.ai/api/v1/chat/completions \
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
          content:("Explain this code in very simple words. Keep it to 2-4 short bullet points with only practical meaning. Code:\n\n" + $t)
        }
      ]
    }')" \
  | jq -r '.choices[0].message.content'
