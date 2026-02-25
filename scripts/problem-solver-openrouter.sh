#!/usr/bin/env bash

# OpenRouter problem-solver command for lazy-reader (consumed via builtins.readFile)
# Reads selected text from stdin and prints a concise, practical answer to stdout.
input="$(cat)"
model="${LAZY_READER_PROBLEM_SOLVER_MODEL:-x-ai/grok-4.1-fast}"
max_tokens="${LAZY_READER_PROBLEM_SOLVER_MAX_TOKENS:-2400}"
temperature="${LAZY_READER_PROBLEM_SOLVER_TEMPERATURE:-0.2}"

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
          content:("You are a practical assistant. The user will provide selected text that likely contains a question, task, bug, or problem statement. Produce a thoughtful, concrete answer with clear steps and a short rationale. Keep it concise enough to be read aloud. Avoid markdown, bullet lists, and code fences. Use plain spoken language.\n\nSelected text:\n\n" + $t)
        }
      ]
    }')" \
  | jq -r '.choices[0].message.content'
