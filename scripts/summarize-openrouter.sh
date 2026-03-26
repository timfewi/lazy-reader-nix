#!/usr/bin/env bash

# OpenRouter summarize command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints a concise spoken summary to stdout.
input="$(cat)"
model="${LAZY_READER_SUMMARIZE_MODEL:-x-ai/grok-4.20-multi-agent-beta}"
max_tokens="${LAZY_READER_SUMMARIZE_MAX_TOKENS:-2200}"
temperature="${LAZY_READER_SUMMARIZE_TEMPERATURE:-0.15}"

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
          content:("Summarize the following passage for listening aloud. Compress it into a clear spoken summary that keeps the main point, the most important supporting details, and any conclusion or next step. Prefer short paragraphs or a smooth spoken flow rather than a list. Do not use markdown, bullet points, headings, or code formatting. Avoid reading symbols aloud unless absolutely necessary. If the passage is technical, translate it into plain language while preserving the key meaning. Keep the summary concise but complete enough that someone could understand the passage without hearing every original detail.\n\nPassage:\n\n" + $t)
        }
      ]
    }')" \
  | jq -r '.choices[0].message.content'
