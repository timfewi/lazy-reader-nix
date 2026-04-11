#!/usr/bin/env bash

# OpenRouter ask command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and LAZY_READER_ASK_QUESTION from the environment,
# then prints a concise spoken-language answer to stdout.
input="$(cat)"
model="${LAZY_READER_ASK_MODEL:-x-ai/grok-4.1-fast}"
max_tokens="1200"
temperature="0.2"

curl -sf https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $LAZY_READER_OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg ctx "$input" \
    --arg q "$LAZY_READER_ASK_QUESTION" \
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
          content:("You are a helpful assistant answering a question about a piece of text. Answer in short, natural spoken language suitable for listening aloud. Use plain words and full sentences. Do not use bullet points, markdown, code formatting, or symbols like star, dash, hash, slash, backticks, or braces. Give a concise, direct answer. If context is ambiguous, make one brief assumption and continue.\n\nContext:\n\n" + $ctx + "\n\nQuestion: " + $q)
        }
      ]
    }')" \
  | jq -r '.choices[0].message.content'
