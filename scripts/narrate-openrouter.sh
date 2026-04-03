#!/usr/bin/env bash

# OpenRouter narrate command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints a spoken rewrite to stdout.
input="$(cat)"
model="${LAZY_READER_NARRATE_MODEL:-x-ai/grok-4.1-fast}"
max_tokens="${LAZY_READER_NARRATE_MAX_TOKENS:-1800}"
temperature="${LAZY_READER_NARRATE_TEMPERATURE:-0.12}"

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
          content:("Rewrite the selected text for listening aloud. The input may be prose, technical documentation, code, config, shell commands, logs, or mixed content. Preserve the meaning, intent, and important details, but turn it into smooth natural spoken language. For prose, paraphrase into a clear spoken version. For code or config, explain what it does, call out the important identifiers, files, commands, or values, and mention literal symbols only when they are essential to understanding. Do not recite punctuation, braces, slashes, markdown markers, indentation, or code formatting unless leaving them out would make the meaning wrong. If the text contains steps, describe them in order using short spoken transitions. Keep the tone calm, precise, and easy to follow. No bullet points, markdown, headings, or code fences. Keep the rewrite concise, faithful, and ready to be read aloud.\n\nSelected text:\n\n" + $t)
        }
      ]
    }')" \
  | jq -r '.choices[0].message.content'
