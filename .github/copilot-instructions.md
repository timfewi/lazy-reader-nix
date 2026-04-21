# Copilot Instructions

## What this repo is

A NixOS module (`services.lazy-reader`) that reads highlighted text aloud using local Piper TTS, triggered by a configurable GNOME keyboard shortcut.

`default.nix` is a thin shim that just imports `lazy-reader.nix`.

## Validation commands

```bash
# Primary repo validation
bash tests/run.sh

# Focused shell syntax checks
for f in scripts/lazy-reader.sh scripts/lib/*.sh; do bash -n "$f"; done

# Validate a single shell file
bash -n scripts/lib/tts.sh

# Focused Nix syntax checks
for f in lazy-reader.nix default.nix nix/*.nix; do nix-instantiate --parse "$f"; done

# Full rebuild + smoke test (on a NixOS machine)
sudo nixos-rebuild switch
lazy-reader status
```

## Architecture

### Shell (`scripts/`)

`scripts/lazy-reader.sh` is the entrypoint. It sources lib files from `scripts/lib/` relative to `BASH_SOURCE[0]`, then calls `main "$@"`.

| File                       | Responsibility                                                                                                 |
| -------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `scripts/lib/config.sh`    | `readonly` env-var constants + mutable globals (`PLAYER_PID`, `RESPONSE_FILE`, `OWNS_PID_FILE`)                |
| `scripts/lib/notify.sh`    | `notify()` — desktop notification + stderr                                                                     |
| `scripts/lib/pid.sh`       | PID-file locking: `is_running`, `cleanup_stale_pid_file`, `kill_reader_tree`, `stop_running_reader`, `cleanup` |
| `scripts/lib/selection.sh` | `read_selection` (legacy wl-paste primary → clipboard fallback), `trim_text`                                   |
| `scripts/lib/input.sh`     | Shared input ingestion (`provider` → `stdin` → `primary` → `clipboard`, plus `--text` override)               |
| `scripts/lib/audio.sh`     | `play_audio` (file), `play_audio_stream` (stdin pipe) for mpv/ffplay                                           |
| `scripts/lib/tts.sh`       | `validate_config`, `speak_text` (streaming first, temp-file fallback)                                          |
| `scripts/lib/explainer.sh` | `run_explainer` — pipes selection through `LAZY_READER_EXPLAIN_CMD`                                            |
| `scripts/lib/summarizer.sh` | `run_summarizer` — pipes selection through `LAZY_READER_SUMMARIZE_CMD`                                        |
| `scripts/lib/solver.sh`     | `run_problem_solver` — pipes selection through `LAZY_READER_PROBLEM_SOLVER_CMD`                               |
| `scripts/lib/asker.sh`      | `prompt_question`, `run_asker` — captures a typed follow-up via zenity, exposes `LAZY_READER_ASK_QUESTION`   |
| `scripts/lazy-reader.sh`    | Sources libs; parses `--source`/`--text`; `start_reading`, `explain_selection`, `summarize_selection`, `solve_selection`, `ask_selection`, `main` |

### Nix (`lazy-reader.nix` + `nix/`)

`lazy-reader.nix` is the NixOS module entry point (~20 lines). It imports the four files in `nix/` as pure functions:

| File                  | Returns                                                                             |
| --------------------- | ----------------------------------------------------------------------------------- |
| `nix/options.nix`     | `{ lib }:` → options attrset for `services.lazy-reader.*`                           |
| `nix/script.nix`      | `{ cfg, pkgs, lib }:` → `lazy-reader` `writeShellApplication` derivation            |
| `nix/bind-script.nix` | `{ cfg, pkgs, lib }:` → `lazy-reader-bind-gnome` `writeShellApplication` derivation |
| `nix/service.nix`     | `{ lazyReaderBindScript, lib, cfg }:` → systemd oneshot service attrset             |

The `nix/script.nix` wrapper exports all `LAZY_READER_*` env vars from Nix options, then `exec`s bash with `${../scripts}/lazy-reader.sh`. Using `${../scripts}` (directory path) copies the entire `scripts/` tree into the Nix store so `BASH_SOURCE[0]`-relative sourcing works at runtime.

## Key conventions

- **Adding a new option**: add `mkOption` in `nix/options.nix` → add `export LAZY_READER_*` in `nix/script.nix` text block → add matching `readonly` in `scripts/lib/config.sh`.
- **Env var precedence**: `LAZY_READER_SPEED` (and similar) use `${LAZY_READER_SPEED:-<nix-value>}` so runtime env overrides Nix config.
- **Speed encoding**: Piper uses `--length-scale` which is `1 / speed`; the conversion happens in `speak_text` via `awk`. The same `speed` value is used for local playback in mpv/ffplay.
- **Streaming first, file fallback**: `speak_text` pipes `piper -f -` into the player; only falls back to a temp `.wav` file if streaming fails.
- **Streaming toggle is env-only**: `LAZY_READER_STREAM_PLAYBACK` exists as a runtime env var, but there is no `services.lazy-reader.streamPlayback` Nix option.
- **Current modes**: read, explain, summarize, solve, and ask are all first-class flows with separate GNOME shortcut options.
- **`clearDefaultSuperSInGnome` default is `true`**: the module clears GNOME's own `Super+S` binding to avoid conflicts.
- **No secrets, no machine-specific paths** should be committed.
- Update `README.md` when behavior or options change.
