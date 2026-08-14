#!/usr/bin/env bash
# Refresh the generated OpenRouter TTS model catalogue in docs/tts-providers.md.
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly OUTPUT="${REPO_ROOT}/docs/tts-providers.md"
readonly BEGIN_MARKER="<!-- BEGIN OPENROUTER_TTS_MODELS -->"
readonly END_MARKER="<!-- END OPENROUTER_TTS_MODELS -->"

check_only=0
models_url="${OPENROUTER_MODELS_URL:-https://openrouter.ai/api/v1/models?output_modalities=speech}"
model_url_template="${OPENROUTER_MODEL_URL_TEMPLATE:-}"
if [[ -z "$model_url_template" ]]; then
	model_url_template='https://openrouter.ai/api/v1/model/{model}'
fi

usage() {
	cat <<'EOF'
Usage: scripts/update-openrouter-tts-providers.sh [--check]

Fetch OpenRouter speech-capable models and refresh the generated catalogue in
docs/tts-providers.md. This command needs curl and jq, uses no API key, and
does not run in CI.

Options:
  --check          fail when the generated catalogue is stale; do not write
  -h, --help       show this help

For tests, OPENROUTER_MODELS_URL and OPENROUTER_MODEL_URL_TEMPLATE may point
at fixture URLs. The model template must contain {model}.
EOF
}

fail() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

fetch_json() {
	curl --fail --silent --show-error --location --max-time 30 "$1"
}

while (($#)); do
	case "$1" in
	--check)
		check_only=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		fail "unknown argument: $1"
		;;
	esac
	shift
done

require_command curl
require_command jq
[[ -f "$OUTPUT" ]] || fail "documentation file not found: $OUTPUT"
[[ "$model_url_template" == *"{model}"* ]] || fail "OPENROUTER_MODEL_URL_TEMPLATE must contain {model}"

begin_count="$(grep -Fxc "$BEGIN_MARKER" "$OUTPUT" || true)"
end_count="$(grep -Fxc "$END_MARKER" "$OUTPUT" || true)"
[[ "$begin_count" == 1 && "$end_count" == 1 ]] || fail "expected one generated catalogue marker pair in $OUTPUT"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
models_json="$work_dir/models.json"
section="$work_dir/section.md"
candidate="$work_dir/candidate.md"

fetch_json "$models_url" >"$models_json"
jq -e '.data | type == "array"' "$models_json" >/dev/null || fail "models response has no data array"

mapfile -t models < <(jq -r '
  .data[]
  | select((.architecture.output_modalities? // .output_modalities? // []) | index("speech"))
  | .id
' "$models_json" | LC_ALL=C sort -u)
((${#models[@]})) || fail "models response contains no speech-capable models"

{
	printf '%s\n' "$BEGIN_MARKER"
	printf '%s\n\n' '### Generated OpenRouter TTS catalogue'
	printf '%s\n\n' "Generated from OpenRouter's public Models API. Refresh it manually with \`scripts/update-openrouter-tts-providers.sh\`; \`--check\` verifies that this section is current without changing files."
	printf '%s\n' '| Model | Name | Voices published by API |'
	printf '%s\n' '| --- | --- | --- |'

	for model in "${models[@]}"; do
		model_url="${model_url_template//\{model\}/$model}"
		model_json="$work_dir/${model//\//_}.json"
		fetch_json "$model_url" >"$model_json"
		jq -e '.data | type == "object"' "$model_json" >/dev/null || fail "invalid model response for $model"

		name="$(jq -r '.data.name // .data.id' "$model_json" | tr '\n' ' ')"
		voices="$(jq -r '
  [
    .data.supported_tts_voices?,
    .data.architecture.supported_tts_voices?,
    .data.capabilities.supported_tts_voices?
  ]
  | flatten
  | map(select(type == "string"))
  | unique
  | map("`" + . + "`")
  | join(", ")
' "$model_json")"
		[[ -n "$voices" ]] || voices='Not published by the API'
		printf '| `%s` | %s | %s |\n' "$model" "${name//|/\\|}" "$voices"
	done

	printf '\n%s\n' "$END_MARKER"
} >"$section"

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v section="$section" '
  $0 == begin {
    while ((getline line < section) > 0) print line
    close(section)
    in_section = 1
    next
  }
  $0 == end && in_section {
    in_section = 0
    next
  }
  !in_section { print }
' "$OUTPUT" >"$candidate"

if cmp -s "$OUTPUT" "$candidate"; then
	printf 'OpenRouter TTS catalogue is current: %s\n' "$OUTPUT"
	exit 0
fi

if ((check_only)); then
	printf 'OpenRouter TTS catalogue is stale: %s\n' "$OUTPUT" >&2
	exit 1
fi

mv "$candidate" "$OUTPUT"
printf 'Updated OpenRouter TTS catalogue: %s\n' "$OUTPUT"
