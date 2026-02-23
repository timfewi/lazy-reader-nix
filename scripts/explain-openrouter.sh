#!/usr/bin/env bash

# OpenRouter explain command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints concise explanation to stdout.
input="$(cat)"
model="x-ai/grok-4.1-fast"
max_tokens="1200"
temperature="0.1"

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
          content:("Explain this code in short, natural spoken language for listening. Use 4 to 6 simple sentences. No bullet points, no markdown, no code formatting, and no symbols like star dash hash slash backticks or braces. Use plain words as if a person is speaking. If context is missing, make one brief assumption and continue.\n\nCode:\n\n" + $t)
        }
      ]
    }')" \
  | jq -r '.choices[0].message.content'
