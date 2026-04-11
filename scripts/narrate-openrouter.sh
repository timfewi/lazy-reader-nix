#!/usr/bin/env bash
set -o pipefail

# OpenRouter narrate command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints a faithful spoken rendering to stdout.
input="$(cat)"
model="${LAZY_READER_NARRATE_MODEL:-x-ai/grok-4.1-fast}"
max_tokens="${LAZY_READER_NARRATE_MAX_TOKENS:-2400}"
temperature="${LAZY_READER_NARRATE_TEMPERATURE:-0.12}"

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
          content:("You are a faithful spoken renderer of technical documentation and source code. Rewrite the selected text for listening aloud without adding information that is not explicitly present in the text. Do not invent behavior, examples, missing context, or background knowledge about the language, library, tool, or framework. For prose, keep the wording close to the original while smoothing formatting into natural spoken sentences. For code, config, shell commands, logs, or mixed technical text, describe only what is visible in the selected text and preserve every identifier, function name, option name, flag, exact value, file path, and command in the order they appear. Do not drop, merge, or paraphrase those tokens. Omit low-value punctuation, braces, brackets, indentation noise, markdown markers, and code fences unless saying them is required to avoid changing the meaning. For mixed prose and code, handle each segment in order without reordering or combining them. If the text describes steps, preserve their sequence using short spoken transitions like first, then, next, and finally. If something is unclear from the selected text alone, say only what is explicitly visible instead of guessing. Keep the tone calm, precise, concise, source-faithful, and ready to be read aloud. No bullet points, markdown, headings, or code fences.\n\nSelected text:\n\n" + $t)
        }
      ]
    }')") || { echo "OpenRouter API request failed. Check LAZY_READER_OPENROUTER_API_KEY and network." >&2; exit 1; }

content=$(echo "$response" | jq -r '.choices[0].message.content')
if [[ -z "$content" || "$content" == "null" ]]; then
  echo "OpenRouter returned empty or null content. Response: $response" >&2
  exit 1
fi
echo "$content"
