---
phase: current
reviewed: 2026-06-09T21:10:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - README.md
  - docs/tts-providers.md
  - nix/bind-script.nix
  - nix/script.nix
  - scripts/lazy-reader.sh
  - scripts/lib/narrator.sh
  - scripts/lib/tts.sh
  - tests/bats/lib/tts.bats
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Code Review Report

**Reviewed:** 2026-06-09T21:10:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This commit fixes 4 bugs (OpenRouter TTS error body piped to player, PID file TOCTOU race, Nix wrapper quoting, TTS config re-read overwrite) and updates 7 tests plus documentation. The four intended fixes are **mostly correct** with one critical regression:

1. **OpenRouter TTS** — temp file + `--max-time`/`--retry` + HTTP status classification is correct in spirit, but **`--fail-with-body` triggers `set -e` before error handling code can execute** (CRITICAL).
2. **PID file** — noclobber atomic write is correct. Edge case: stale PID overwrite reverts to non-atomic write (acceptable, rare path).
3. **Nix wrapper** — single-quote→double-quote fix is correct; bash variable expansion now works.
4. **TTS defaults** — `load_tts_config()` now preserves existing values. Correct.

Test coverage is adequate for the happy path but has gaps in error handling (only 429 tested, missing 401/403/5xx/network failure).

---

## Critical Issues

### CR-01: `--fail-with-body` causes premature `set -e` abort on HTTP error (OpenRouter TTS)

**File:** `scripts/lib/tts.sh:262-270`
**Issue:** The curl invocation uses `--fail-with-body`, which causes curl to exit with code 22 on any HTTP 4xx/5xx response. The command substitution `http_code="$(curl ...)"` propagates this non-zero exit from the subshell. Because `lazy-reader.sh` runs with `set -e` (line 2), the whole script aborts _before_ the HTTP status classification at line 272 is ever reached. Users see no notification — the process silently dies.

The error handling block (lines 272-288) is dead code in production because `set -e` kills the process first. The tests pass only because they invoke lib functions directly under `bash -c` without `set -e`, masking this bug.

**Fix:** Remove `--fail-with-body` from the curl arguments. The manual `http_code` check at line 272 already handles non-2xx responses. Without `--fail-with-body`, curl treats 4xx/5xx as valid HTTP transactions and exits 0, keeping the error classification code reachable.

```diff
-	http_code="$(curl --max-time 60 --connect-timeout 10 --retry 2 --retry-delay 1 \
-		--write-out "%{http_code}" \
-		--silent --show-error \
-		--fail-with-body \
-		https://openrouter.ai/api/v1/audio/speech \
-		-H "Authorization: Bearer $api_key" \
-		-H "Content-Type: application/json" \
-		-d "$payload" \
-		--output "$tmpfile" 2>/dev/null)"
+	http_code="$(curl --max-time 60 --connect-timeout 10 --retry 2 --retry-delay 1 \
+		--write-out "%{http_code}" \
+		--silent --show-error \
+		https://openrouter.ai/api/v1/audio/speech \
+		-H "Authorization: Bearer $api_key" \
+		-H "Content-Type: application/json" \
+		-d "$payload" \
+		--output "$tmpfile" 2>/dev/null)"
```

---

## Warnings

### WR-01: Response body discarded on HTTP error

**File:** `scripts/lib/tts.sh:273,304`
**Issue:** When curl receives an HTTP error (4xx/5xx), the response body is written to `$tmpfile` but then immediately deleted without being read (`rm -f "$tmpfile"` at line 273). This loses the OpenRouter error message (e.g., `{"error":"invalid voice for model","details":"..."}`), which was visible in the old pipe-to-player approach.

The user now gets only the HTTP status code classification ("rate limited (HTTP 429)") instead of the provider's specific error message. The 401/403/5xx cases similarly lose detail.

**Fix:** Read the response body from `$tmpfile` before deleting on error and include it in the notification. Alternatively, move the temp file to a known path for diagnostics:

```diff
 	if ! [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
+		local error_body
+		error_body="$(<"$tmpfile")"
 		rm -f "$tmpfile"
+		# Truncate long error bodies to avoid notification toast overflow
+		error_body="${error_body:0:200}"
 		case "$http_code" in
 		401 | 403)
-			notify "OpenRouter TTS: API key rejected (HTTP $http_code). Check LAZY_READER_OPENROUTER_API_KEY."
+			notify "OpenRouter TTS: API key rejected (HTTP $http_code): $error_body"
 			;;
 		429)
-			notify "OpenRouter TTS: rate limited (HTTP 429). Wait and try again."
+			notify "OpenRouter TTS: rate limited (HTTP 429): $error_body"
 			;;
 		5*)
-			notify "OpenRouter TTS: server error (HTTP $http_code). Try again later."
+			notify "OpenRouter TTS: server error (HTTP $http_code): $error_body"
 			;;
 		*)
-			notify "OpenRouter TTS request failed (HTTP $http_code)."
+			notify "OpenRouter TTS request failed (HTTP $http_code): $error_body"
 			;;
 		esac
```

### WR-02: Stale PID fallback reintroduces non-atomic write

**File:** `scripts/lazy-reader.sh:319`
**Issue:** The noclobber atomic write correctly prevents two processes racing for the PID file. However, the stale-PID fallback at line 319:

```bash
echo "$$" >"$PID_FILE"
```

reverts to a plain overwrite without noclobber. In the unlikely scenario where two processes both detect a stale PID simultaneously (the stored PID died, both check kill -0 at the same time, both fall through), this recreates the same TOCTOU race the noclobber fix was supposed to eliminate.

Probability is low (stale PID only occurs on crashes), but the fix is simple.

**Fix:** Use the same noclobber pattern for the stale PID overwrite:

```diff
 		# Stale PID from dead process — overwrite.
+		(
+			set -o noclobber
+			echo "$$" >"$PID_FILE"
+		) 2>/dev/null || {
+			# Lost race — another process just claimed it.
+			notify "Already reading. Press shortcut to stop."
+			exit 0
+		}
-		echo "$$" >"$PID_FILE"
 	fi
```

---

## Info

### IN-01: `mktemp --suffix` is GNU coreutils-specific

**File:** `scripts/lib/tts.sh:259`
**Issue:** `mktemp --suffix=...` is a GNU coreutils extension (not POSIX). The Nix wrapper includes `coreutils` so this is fine in production, but the script is also callable outside Nix (e.g., by sourcing it directly or running tests). If someone runs it on a BSD/macOS system, `mktemp` may reject the `--suffix` flag.

The `--suffix` flag is also used in `_speak_piper` at line 190 and the `ask_selection` mktemp at `lazy-reader.sh:231`, so this is a pre-existing pattern.

**Suggestion:** Document the `coreutils` requirement or use a portable alternative (`TMPDIR`, `.XXXXX` template) if cross-platform support is desired. For this project's scope (NixOS), the risk is acceptable.

### IN-02: Error response body lost in test refactor

**File:** `tests/bats/lib/tts.bats:290-327`
**Issue:** The failure test was simplified from checking for the detailed response body:

```
# OLD:  [[ "$output" == *"OpenRouter TTS request failed (HTTP 400): {\"error\":\"invalid voice\"}"* ]]
# NEW:  [[ "$output" == *"rate limited (HTTP 429)"* ]]
```

Only the 429 case is tested. The 401/403, 5xx, and generic-failure paths are uncovered. Additionally, the stub exits 22 (mimicking `--fail-with-body`), but since the tests don't use `set -e`, this doesn't catch the CR-01 bug.

**Suggestion:** Add parameterized test cases for each HTTP status class (401, 403, 500, 000-for-network-error). If response body inclusion from WR-01 is implemented, also test that the body appears in the notification.

### IN-03: README pipeline diagram stale arrow text

**File:** `README.md:33`
**Issue:** The pipeline diagram now reads "│ each chunk" on line 33, but the "each chunk" text is a leftover from the old chunking pipeline. With the removed chunking lines above, the arrow now says "│ each chunk" pointing from the trim step directly to the TTS engine, which is slightly misleading — there is no chunking happening in the pipeline anymore (the removal of lines 33-34 confirms this). The word "each" implies multiple iterations that don't occur.

**Suggestion:** Change "│ each chunk" to "│ text" or simply remove that line:

```
 ┌──────────────────┬──────────────────────────┘
-                    │ each chunk
+                    │
                     ▼
```

---

## Fix Verification Summary

| Bug # | Description                               | Correct? | Notes                                                             |
| ----- | ----------------------------------------- | -------- | ----------------------------------------------------------------- |
| 1a    | OpenRouter: curl timeout/retry            | ✅       | `--max-time 60 --connect-timeout 10 --retry 2 --retry-delay 1`    |
| 1b    | OpenRouter: temp file (no pipe-to-player) | ✅       | Prevents error body from corrupting audio player                  |
| 1c    | OpenRouter: HTTP status classification    | ❌ CR-01 | `--fail-with-body` + `set -e` kills process before classification |
| 1d    | OpenRouter: error body lost               | ⚠️ WR-01 | Temp file deleted without reading on error                        |
| 2     | PID file: noclobber atomic write          | ✅       | Correct race-free claim                                           |
| 3     | Nix wrapper: single→double quotes         | ✅       | Now properly expands bash vars                                    |
| 4     | TTS defaults: preserve existing values    | ✅       | Chained fallbacks correct                                         |

## Test Coverage Gaps

| Area                              | Coverage   | Gap                                          |
| --------------------------------- | ---------- | -------------------------------------------- |
| OpenRouter MP3 success            | ✅ 3 tests | —                                            |
| OpenRouter PCM success            | ✅ 2 tests | —                                            |
| PCM uses aplay, not PLAYER        | ✅ 1 test  | —                                            |
| HTTP 429 error                    | ✅ 1 test  | Stub exits 22, but test doesn't use `set -e` |
| HTTP 401/403 error                | ❌         | Not tested (CR-01 affects this path)         |
| HTTP 5xx error                    | ❌         | Not tested                                   |
| Network failure (curl no-connect) | ❌         | Not tested                                   |
| curl timeout                      | ❌         | Not tested                                   |
| curl retry exhausted              | ❌         | Not tested                                   |

---

## Cross-File Dependencies Impacted

| Change                     | Depends on                                         | Risk                                         |
| -------------------------- | -------------------------------------------------- | -------------------------------------------- | --- | ------------------------------------- |
| nix/script.nix quote fix   | scripts/lib/config.sh reads LAZY*READER*\* vars    | None — env var names unchanged               |
| load_tts_config() cascade  | config.sh sets TTS_PROVIDER first                  | None — case statement validates after        |
| PID noclobber              | pid.sh cleanup(), cleanup_stale_pid_file()         | None — both use OWNS_PID_FILE flag correctly |
| narrator.sh stderr capture | scripts/lib/narrator.sh called from lazy-reader.sh | None — `                                     |     | exit_code=$?` protects against set -e |

---

_Reviewed: 2026-06-09T21:10:00Z_
_Reviewer: gsd-code-reviewer_
_Depth: standard_
