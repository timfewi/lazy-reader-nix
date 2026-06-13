---
phase: current
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - scripts/master-openrouter.sh
  - scripts/lib/master.sh
  - scripts/lazy-reader.sh
  - scripts/lib/selection.sh
  - scripts/lib/config.sh
  - nix/options.nix
  - nix/script.nix
  - nix/bind-script.nix
  - modules/voice-tools.nix
findings:
  critical: 2
  warning: 6
  info: 3
  total: 11
status: issues_found
---

# Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Master mode is wired end-to-end (options, wrapper, binding, lazy-reader dispatch, and the OpenRouter helper), but it ships with one Nix evaluation bug that breaks the default module configuration and several robustness/consistency gaps in bash key handling, diagnostics, and shortcut clearing.

## Critical Issues

### CR-01: `nix/script.nix` fails Nix evaluation when `openRouterApiKeyFile` is unset

**File:** `nix/script.nix:60`
**Issue:** `${cfg.openRouterApiKeyFile or ""}` does **not** fall back to `""` when the option value is `null`; `or` only substitutes a missing attribute. Because `openRouterApiKeyFile` defaults to `null`, enabling `services.lazy-reader` without setting the key file causes `cannot coerce null to a string` during evaluation. This is a hard build error for the default config.

**Fix:** Use `lib.optionalString` to skip the interpolation when the option is `null`:

```nix
export LAZY_READER_OPENROUTER_API_KEY_FILE="''${LAZY_READER_OPENROUTER_API_KEY_FILE:-${
  lib.optionalString (cfg.openRouterApiKeyFile != null) cfg.openRouterApiKeyFile
}}"
```

### CR-02: OpenRouter API key file is read without trimming trailing whitespace

**File:** `scripts/lib/config.sh:26`, `scripts/lib/tts.sh:233`
**Issue:** Both code paths read the key file with `$(<...)` / `cat`. If the secret file ends with a newline (common for files created with `echo` or editors), the exported/used key contains `\n`. The `Authorization: Bearer ...` header then includes a newline, which either corrupts the HTTP request or causes OpenRouter to reject every request in all OpenRouter-backed modes (explain, ask, master, TTS).

**Fix:** Trim whitespace after reading:

```bash
# scripts/lib/config.sh:26
key="$(<"$openrouter_api_key_file")"
export LAZY_READER_OPENROUTER_API_KEY="${key%$'\n'}"
```

```bash
# scripts/lib/tts.sh:233
api_key="$(cat "$LAZY_READER_OPENROUTER_API_KEY_FILE")"
api_key="${api_key%$'\n'}"
```

## Warnings

### WR-01: Master command discards stderr, hiding failure reasons

**File:** `scripts/lib/master.sh:12`
**Issue:** `bash -c "$MASTER_CMD" 2>/dev/null` swallows all stderr. If `master-openrouter.sh` fails, the user gets only "Master command failed" with no actionable detail. The existing `narrator.sh` already captures stderr to a temp file and reports it.

**Fix:** Capture stderr like `narrator.sh`:

```bash
local stderr_file
stderr_file="$(mktemp)"
if ! master_text="$(printf '%s' "$input_text" | bash -c "$MASTER_CMD" 2>"$stderr_file")"; then
  local error_msg
  error_msg="$(<"$stderr_file")"
  rm -f "$stderr_file"
  notify "Master command failed: ${error_msg:-check services.lazy-reader.masterCommand}"
  exit 1
fi
rm -f "$stderr_file"
```

### WR-02: OpenRouter TTS playback ignores the configured `audioPlayer`

**File:** `scripts/lib/tts.sh:297`, `scripts/lib/tts.sh:303`
**Issue:** For MP3 responses `_speak_openrouter` always calls `mpv`; for PCM it always calls `aplay`, regardless of the `LAZY_READER_PLAYER` setting. A user who sets `audioPlayer = "ffplay"` still gets `mpv`/`aplay`.

**Fix:** Route through `play_audio`/`play_audio_stream` with the correct format, or branch on `$PLAYER` inside `_speak_openrouter`:

```bash
if [[ "$response_format" == "pcm" ]]; then
  play_audio "$tmpfile" "pcm"
else
  play_audio "$tmpfile"
fi
```

### WR-03: Disabling default-shortcut clearing still emits a broken `gsettings set`

**File:** `nix/bind-script.nix:28`, `nix/bind-script.nix:96`, `nix/bind-script.nix:110`
**Issue:** `clearShortcut` is produced by `lib.optionalString`, so it becomes `""` when disabled. The guard `clearShortcut != null` is therefore true even when `clearShortcut` is empty, generating `gsettings set  "[]" || true` for the default shortcuts. The `|| true` masks the failure, but it prints noise/errors and is brittle.

**Fix:** Either pass `null` when disabled, or guard on a non-empty string:

```nix
${lib.optionalString (clearShortcut != null && clearShortcut != "") ''
  if [[ "${shortcut}" == "${clearCheck}" ]]; then
    gsettings set ${clearShortcut} "[]" || true
  fi
''}
```

### WR-04: `master-openrouter.sh` sends an unexplained `zdr:true` flag

**File:** `scripts/master-openrouter.sh:23`
**Issue:** The chat-completions payload includes `zdr: true`, which no other OpenRouter helper script sets. If OpenRouter rejects unknown top-level fields, master mode will fail while the other modes work. If it is intentional, it is undocumented and inconsistent.

**Fix:** Remove `zdr: true` unless it is a documented, required OpenRouter parameter; if required, add a comment and use it consistently across all OpenRouter scripts.

### WR-05: Master mode ignores `--input-source` and always reads clipboard

**File:** `scripts/lazy-reader.sh:272`
**Issue:** `master_selection` hardcodes `"clipboard"` as the third argument to `require_input_text`, so `--stdin` or `--input-source selection` are silently ignored for master mode. The usage line implies modes compose with input sources.

**Fix:** Use `$INPUT_SOURCE` unless master is intentionally clipboard-only:

```bash
text="$(require_input_text "No text found. Copy or select text first, then press Super+M." "$MASTER_INPUT_MAX_CHARS" "$INPUT_SOURCE")"
```

If clipboard-only is by design, document it in the usage string and reject incompatible input sources explicitly.

### WR-06: Master helper lacks strict bash options and numeric env validation

**File:** `scripts/master-openrouter.sh:2`, `scripts/master-openrouter.sh:17-18`
**Issue:** Only `set -o pipefail` is set, so unset-variable or other failures do not abort. More importantly, `max_tokens` and `temperature` are passed to `jq --argjson` without validation; a non-numeric `LAZY_READER_MASTER_MAX_TOKENS` causes a raw jq error instead of a friendly notification.

**Fix:** Add `set -euo pipefail` and validate numbers before jq:

```bash
set -euo pipefail

if ! [[ "$max_tokens" =~ ^[0-9]+$ ]]; then
  echo "Invalid LAZY_READER_MASTER_MAX_TOKENS: $max_tokens" >&2
  exit 1
fi
if ! [[ "$temperature" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid LAZY_READER_MASTER_TEMPERATURE: $temperature" >&2
  exit 1
fi
```

## Info

### IN-01: `masterCommand` option description is misleading

**File:** `nix/options.nix:320-327`
**Issue:** The description says the command "Sends clipboard text to OpenRouter API for LLM summarization", but the option is generic: any shell command that reads stdin and writes stdout works. The wording couples the option to a specific backend and input source.

**Fix:** Reword to match the generic command style used for `explainCommand`/`summarizeCommand`.

### IN-02: Usage string omits the `clipboard` input source

**File:** `scripts/lazy-reader.sh:39`
**Issue:** `parse_args` accepts `clipboard`, but the usage line only lists `selection|stdin`.

**Fix:** Update usage to `[--stdin|--input-source selection|stdin|clipboard]`.

### IN-03: No Nix option for master model/max-tokens/temperature

**File:** `nix/options.nix`, `modules/voice-tools.nix`
**Issue:** `master-openrouter.sh` uses `LAZY_READER_MASTER_MODEL`, `LAZY_READER_MASTER_MAX_TOKENS`, and `LAZY_READER_MASTER_TEMPERATURE`. `voice-tools.nix` only sets the model via `environment.sessionVariables`; the token/temperature defaults are hardcoded in the script. For consistency with other modes, consider Nix options or at least env vars in `voice-tools.nix`.

---

_Reviewed: 2026-06-13_
_Reviewer: gsd-code-reviewer_
_Depth: standard_
