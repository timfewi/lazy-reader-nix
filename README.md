# lazy-reader-nix

Reads currently selected text out loud with local Piper Text-to-Speech when you press `Super+S` (GNOME Wayland).

## What this repo provides

- `lazy-reader.nix`: NixOS module (`services.lazy-reader`)
- `scripts/lazy-reader.sh`: runtime script that:
  - gets selected text from Wayland selection (`wl-paste --primary`) with clipboard fallback,
  - synthesizes speech locally with `piper`,
  - plays returned audio via `mpv` or `ffplay`.
- GNOME binding automation via user systemd service.

## Enable in NixOS

Import the module in your NixOS config:

```nix
# configuration.nix
{
  imports = [
    /path/to/lazy-reader-nix/lazy-reader.nix
  ];

  services.lazy-reader = {
    enable = true;
    gnomeShortcut = "<Super>s";
    # clearDefaultSuperSInGnome = true;
    speed = 1.20;

    # Optional
    # autoBindInGnome = true;
    # model = "/var/lib/piper/en_US-lessac-medium.onnx";
    # modelConfig = "/var/lib/piper/en_US-lessac-medium.onnx.json";
    # modelUrl = "https://.../en_US-lessac-medium.onnx";
    # modelSha256 = "sha256-...";
    # modelConfigUrl = "https://.../en_US-lessac-medium.onnx.json";
    # modelConfigSha256 = "sha256-...";
    # speaker = 0;
    # audioPlayer = "mpv";
    # streamPlayback = true;
    enableExplainInGnome = true;
    gnomeExplainShortcut = "<Super>a";
    explainCommand = builtins.readFile /home/tim/projects/lazy-reader-nix/scripts/explain-openrouter.sh;

    # enableProblemSolverInGnome = true;     # set to true to register Super+Q binding
    # gnomeProblemSolverShortcut = "<Super>q"; # default shortcut for solver mode
    # clearDefaultSuperQInGnome = true; # removes <Super>q from GNOME window-close binding
    # problemSolverCommand = builtins.readFile /home/tim/projects/lazy-reader-nix/scripts/problem-solver-openrouter.sh;
    # problemSolverMaxChars = 2400;
  };
}
```

If you clone this repository and keep `configuration.nix` in the same repo tree, you can also import `./lazy-reader.nix`.

Apply changes:

```bash
sudo nixos-rebuild switch
```

## Set a local Piper model

Point `services.lazy-reader.model` to a local Piper `.onnx` file.

Example:

```nix
services.lazy-reader.model = "/var/lib/piper/en_US-lessac-medium.onnx";
services.lazy-reader.modelConfig = "/var/lib/piper/en_US-lessac-medium.onnx.json";
services.lazy-reader.speaker = 0;
```

If `modelConfig` is omitted, Piper tries to auto-detect it.

## Fetch model directly from URL (recommended for easy switching)

You can configure the model as URL + hash directly in the module.
Nix will fetch it into the store, and lazy-reader uses the local store path at runtime.

```nix
services.lazy-reader = {
  modelUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx";
  modelSha256 = "17q1mzm6xd5i2rxx2xwqkxvfx796kmp1lvk4mwkph602k7k0kzjy";

  modelConfigUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json";
  modelConfigSha256 = "184hnvd8389xpdm0x2w6phss23v5pb34i0lhd4nmy1gdgd0rrqgg";
};
```

When both path- and URL-based options are set, URL-based options take precedence.

## Behavior

1. Highlight text with mouse in any window.
2. Press `Super+S` to start reading.
3. Press `Super+S` again while reading to stop immediately.
4. (Optional) Press `Super+A` (when `enableExplainInGnome = true`) to explain selected code/text and read the explanation aloud.
5. (Optional) Press `Super+Q` (when `enableProblemSolverInGnome = true`) to generate a concise solution/answer and read it aloud.
6. (Optional) Press `Super+Shift+A` (when `enableAskInGnome = true`) to ask a typed follow-up question about the selected text and hear the answer.
7. Press the same shortcut again while running (`Super+S`, `Super+A`, `Super+Q`, or `Super+Shift+A`) to stop/cancel immediately.

If no text is selected, it shows a notification.

## Quick test (without hotkey)

Run this first to verify local synthesis + audio work:

```bash
wl-copy --primary "Hello, this is a lazy reader test."
lazy-reader
```

Manual controls:

```bash
lazy-reader start
lazy-reader stop
lazy-reader status
lazy-reader explain
lazy-reader solve
lazy-reader ask
```

If this works, your script is fine and only keybinding setup remains.

## Make reading faster

Set speed in Nix and rebuild:

```nix
services.lazy-reader.speed = 1.3;
```

`1.0` is normal speed, `1.3` / `1.4` are faster.
Runtime env vars also accept aliases: `slow` (`0.8`), `normal` (`1.0`), `fast` (`1.4`).

Default is now `1.4` if you do not set anything.

`speed` now controls both Piper synthesis speed and local playback speed.

You can also override at runtime (because shortcut runs through `zsh -lc`):

```bash
export LAZY_READER_SPEED=1.3
export LAZY_READER_STREAM_PLAYBACK=1
```

Priority is env var first, then Nix option (`LAZY_READER_SPEED` / `services.lazy-reader.speed`).

`LAZY_READER_PLAYBACK_SPEED` is still accepted as a legacy fallback for compatibility, but `LAZY_READER_SPEED` is preferred.

### Explain mode (selected snippet → explanation → speech)

Explain mode is disabled until you configure an explainer command.

The command must:

- read selected text from stdin,
- print the explanation to stdout.

Example with a local Ollama model:

```nix
services.lazy-reader = {
  enableExplainInGnome = true;
  gnomeExplainShortcut = "<Super>a";  # default
  explainCommand = ''
    ollama run qwen2.5-coder:7b "Explain this code in simple terms:\n$(cat)"
  '';
};
```

Example with OpenRouter command moved into this repo (cleaner `configuration.nix`):

```nix
services.lazy-reader = {
  enableExplainInGnome = true;
  gnomeExplainShortcut = "<Super>a";
  explainMaxChars = 1000; # recommended 700-1200 for lower latency
  explainCommand = builtins.readFile /home/tim/projects/lazy-reader-nix/scripts/explain-openrouter.sh;
};
```

Optional runtime tuning vars for the OpenRouter script:

- `LAZY_READER_OPENROUTER_API_KEY` (required)

Current defaults in `scripts/explain-openrouter.sh` are fixed to:

- model: `x-ai/grok-4.1-fast`
- max tokens: `1200`
- temperature: `0.1`

If you want these configurable via environment variables, edit that script.

Default explain hotkey in GNOME is `services.lazy-reader.gnomeExplainShortcut = "<Super>a"` (GNOME app grid is cleared automatically via `clearDefaultSuperAInGnome = true`).

### Problem-solver mode (selected snippet → thoughtful answer → speech)

Problem-solver mode is disabled until you configure a solver command.

The command must:

- read selected text from stdin,
- print the answer/solution to stdout.

Example with a local Ollama model:

```nix
services.lazy-reader = {
  enableProblemSolverInGnome = true;
  gnomeProblemSolverShortcut = "<Super>q";  # default
  problemSolverCommand = ''
    ollama run qwen2.5-coder:7b "Give a practical solution to this:\n$(cat)"
  '';
};
```

Example with OpenRouter command moved into this repo:

```nix
services.lazy-reader = {
  enableProblemSolverInGnome = true;
  gnomeProblemSolverShortcut = "<Super>q";
  problemSolverMaxChars = 1200;
  problemSolverCommand = builtins.readFile /home/tim/projects/lazy-reader-nix/scripts/problem-solver-openrouter.sh;
};
```

Optional runtime tuning vars for the OpenRouter solver script:

- `LAZY_READER_PROBLEM_SOLVER_MODEL` (default: `x-ai/grok-4.1-fast`)
- `LAZY_READER_PROBLEM_SOLVER_MAX_TOKENS` (default: `1600`)
- `LAZY_READER_PROBLEM_SOLVER_TEMPERATURE` (default: `0.12`)
- `LAZY_READER_OPENROUTER_API_KEY` (required)

Default solver hotkey in GNOME is `services.lazy-reader.gnomeProblemSolverShortcut = "<Super>q"`.
When using `Super+Q`, the module can remove GNOME's default close-window conflict automatically via `clearDefaultSuperQInGnome = true`.

### Ask mode (selected text + typed question → answer → speech)

Ask mode lets you highlight a passage, press `Super+Shift+A`, type a free-form question in a small GNOME dialog, and hear the answer spoken aloud.  It is distinct from explain mode: explain summarises; ask answers your specific question.

Ask mode is disabled until you configure an ask command.

The command must:

- read selected text from **stdin**,
- read the user's typed question from the **`LAZY_READER_ASK_QUESTION`** environment variable,
- print the answer to stdout.

Example with a local Ollama model:

```nix
services.lazy-reader = {
  enableAskInGnome = true;
  gnomeAskShortcut = "<Super><Shift>a";  # default
  askCommand = ''
    ollama run qwen2.5-coder:7b \
      "Context:\n$(cat)\n\nQuestion: $LAZY_READER_ASK_QUESTION\n\nAnswer concisely."
  '';
};
```

Example with OpenRouter command moved into this repo (cleaner `configuration.nix`):

```nix
services.lazy-reader = {
  enableAskInGnome = true;
  gnomeAskShortcut = "<Super><Shift>a";  # default
  askMaxChars = 1200;
  askCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/ask-openrouter.sh;
};
```

Optional runtime tuning vars for the OpenRouter ask script:

- `LAZY_READER_OPENROUTER_API_KEY` (required)

Current defaults in `scripts/ask-openrouter.sh` are fixed to:

- model: `x-ai/grok-4.1-fast`
- max tokens: `1200`
- temperature: `0.2`

If you want these configurable via environment variables, edit that script.

**Command contract summary:**

| Channel | Content |
|---------|---------|
| stdin | Selected text (trimmed to `maxChars`) |
| `LAZY_READER_ASK_QUESTION` env var | Typed question from the zenity dialog |
| stdout | Answer text (trimmed to `askMaxChars`, then spoken) |

**Flow:**
1. Press `Super+Shift+A` — script captures selected text.
2. A small `zenity` entry dialog appears: *"Your question about the selected text:"*
3. Type your question and press Enter (or Cancel to abort gracefully).
4. The ask command runs with the text on stdin and the question in `LAZY_READER_ASK_QUESTION`.
5. The answer is spoken aloud by Piper TTS.

Quick manual test:

```bash
wl-copy --primary "The mitochondria is the powerhouse of the cell."
LAZY_READER_ASK_CMD='printf "It produces ATP via cellular respiration."' lazy-reader ask
```

After running `lazy-reader ask`, type your question into the Zenity prompt so the command can answer it in context.

## Verify GNOME keybinding state

Check whether GNOME still owns `Super+S`:

```bash
gsettings get org.gnome.shell.keybindings toggle-quick-settings
```

Force-remove GNOME default binding and re-apply lazy-reader binding:

```bash
gsettings set org.gnome.shell.keybindings toggle-quick-settings "[]"
systemctl --user restart lazy-reader-bind-gnome.service
```

Inspect the bound command:

```bash
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader/ command

# Explain binding (when enableExplainInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-explain/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-explain/ command

# Problem-solver binding (when enableProblemSolverInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-problem-solver/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-problem-solver/ command

# Ask binding (when enableAskInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-ask/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-ask/ command
```

Inspect user service logs:

```bash
systemctl --user status lazy-reader-bind-gnome.service
journalctl --user -u lazy-reader-bind-gnome.service -n 50 --no-pager
```

Re-apply binding immediately (without logout):

```bash
systemctl --user restart lazy-reader-bind-gnome.service
```

If you changed shell env vars or explain/solver command behavior, run that restart command so GNOME re-reads the command binding.

## Troubleshooting

- `Local Piper synthesis failed`:
  - Confirm model path exists and ends with `.onnx`.
  - If you set `services.lazy-reader.modelConfig`, confirm it exists.
  - For multi-speaker models, set a valid `services.lazy-reader.speaker` value.

- `Super+S` still opens GNOME Quick Settings:

  ```bash
  gsettings set org.gnome.shell.keybindings toggle-quick-settings "[]"
  systemctl --user restart lazy-reader-bind-gnome.service
  ```

  You can keep this automated with:

  ```nix
  services.lazy-reader.clearDefaultSuperSInGnome = true;
  ```

- Keybinding not active yet: log out/in once after rebuild, or run:
  ```bash
  systemctl --user restart lazy-reader-bind-gnome.service
  ```
- Missing notifications: ensure notification daemon is running in desktop session.
- No audio: switch player:
  ```nix
  services.lazy-reader.audioPlayer = "ffplay";
  ```
- Selection empty in some apps: select text then copy once, script will use clipboard fallback.

## Running the tests

```bash
bash tests/run.sh
```

This runs two suites:

1. **Syntax checks** (`tests/syntax.sh`) — `bash -n` on every shell script and `nix-instantiate --parse` on every Nix file.
2. **Bats unit/integration tests** (`tests/bats/`) — covers `trim_text`, `read_selection`, `is_running`, `cleanup_stale_pid_file`, `validate_config`, `run_explainer`, `run_problem_solver`, `run_asker`, and the main dispatch logic.

`bats` is pulled in automatically via `nix-shell -p bats` if not already on `PATH`.

## License

MIT. See `LICENSE`.

## Contributing

See `CONTRIBUTING.md`.

## Security

See `SECURITY.md` for private vulnerability reporting guidance.
