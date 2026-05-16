# lazy-reader-nix

Reads currently selected text out loud with local Piper Text-to-Speech when you press `Super+S` (GNOME Wayland), with optional narrate, explain, summarize, solve, ask, and teach modes.

## What this repo provides

- `lazy-reader.nix`: NixOS module (`services.lazy-reader`)
- `scripts/lazy-reader.sh`: runtime script that:
  - gets selected text from Wayland selection (`wl-paste --primary`) with clipboard fallback,
  - synthesizes speech locally with `piper`,
  - plays returned audio via `mpv` or `ffplay`.
- GNOME binding automation via user systemd service.

## Privacy and optional hosted backends

Core text-to-speech playback is local: Piper runs on your machine and audio stays local.

The optional bundled `*-openrouter.sh` helper scripts are different: they send the
selected text to OpenRouter before the spoken result comes back. Keep API keys in
environment variables, not tracked files, and only use hosted helpers for text you
are comfortable sending to a third-party service.

For runtime TTS provider/model/voice switching, see
[TTS providers, models, and voices](docs/tts-providers.md).

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
    openRouterApiKeyFile = "/run/agenix/lazy-reader-openrouter-api-key";
    # clearDefaultSuperSInGnome = true;
    speed = 1.20;
    # playbackSpeed = 1.0;

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
    enableNarrateInGnome = true;
    gnomeNarrateShortcut = "<Super>e";
    narrateCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/narrate-openrouter.sh;
    enableExplainInGnome = true;
    gnomeExplainShortcut = "<Super>a";
    explainCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/explain-openrouter.sh;
    enableSummarizeInGnome = true;
    gnomeSummarizeShortcut = "<Super>w";
    summarizeInputMaxChars = 6000;
    summarizeCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/summarize-openrouter.sh;
    # enableAskInGnome = true;
    # gnomeAskShortcut = "<Super><Shift>a";
    # askCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/ask-openrouter.sh;

    # enableProblemSolverInGnome = true;     # set to true to register Super+Q binding
    # gnomeProblemSolverShortcut = "<Super>q"; # default shortcut for solver mode
    # clearDefaultSuperQInGnome = true; # removes <Super>q from GNOME window-close binding
    # problemSolverCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/problem-solver-openrouter.sh;
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
2. Press `Super+S` to start reading. Longer plain-reader selections are spoken in sentence/paragraph-aware Piper chunks instead of being hard-cut at one raw character limit. If the selection contains code-like blocks and you have `explainCommand` or `narrateCommand` configured, those parts are spoken in natural language instead of being read symbol-by-symbol.
3. Press `Super+S` again while reading to stop immediately.
4. (Optional) Press `Super+E` (when `enableNarrateInGnome = true`) to rewrite selected docs/code/config into natural spoken language and read that narration aloud.
5. (Optional) Press `Super+A` (when `enableExplainInGnome = true`) to explain a shorter selected snippet and read the clarification aloud.
6. (Optional) Press `Super+W` (when `enableSummarizeInGnome = true`) to compress a longer selected passage into a spoken summary.
7. (Optional) Press `Super+Q` (when `enableProblemSolverInGnome = true`) to generate a concise solution/answer and read it aloud.
8. (Optional) Press `Super+Shift+A` (when `enableAskInGnome = true`) to ask a typed follow-up question about the selected text and hear the answer.
9. (Optional) Press `Super+P` (when `enableTeachInGnome = true`) to get a plain-language ELI5 explanation of a selected book page and hear it aloud.
10. Press the same shortcut again while running (`Super+S`, `Super+E`, `Super+A`, `Super+W`, `Super+Q`, `Super+Shift+A`, or `Super+P`) to stop/cancel immediately.

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
lazy-reader narrate
lazy-reader explain
lazy-reader summarize
lazy-reader solve
lazy-reader ask
lazy-reader teach
```

If this works, your script is fine and only keybinding setup remains.

## Make reading faster

Set speed in Nix and rebuild:

```nix
services.lazy-reader.speed = 1.3;
```

`1.0` is normal speed, `1.3` / `1.4` are faster for Piper synthesis.
Runtime env vars also accept aliases: `slow` (`0.8`), `normal` (`1.0`), `fast` (`1.4`).

Default is now `1.4` if you do not set anything.

`speed` now controls Piper synthesis speed only.

Local playback speed is separate and defaults to natural-speed playback:

```nix
services.lazy-reader.playbackSpeed = 1.0;
```

For OpenRouter TTS, this is the reliable way to increase reading speed across
all models because it speeds up the returned audio locally.

You can set `playbackSpeed = config.services.lazy-reader.speed;` if you want the older combined-speed behavior back.

OpenRouter also accepts a native TTS `speed` parameter for some providers:

```nix
services.lazy-reader.openRouterSpeed = 1.3;
```

OpenRouter documents this as model/provider-dependent. Unsupported providers may
ignore it, so keep using `playbackSpeed` when you need guaranteed faster audio.

OpenRouter response format defaults to `auto`, which uses PCM for Gemini TTS
models and MP3 for other OpenRouter TTS models:

```nix
services.lazy-reader.openRouterResponseFormat = "auto";
```

You can also override at runtime (because the GNOME shortcut runs through `zsh -lc`):

```bash
export LAZY_READER_SPEED=1.0
export LAZY_READER_PLAYBACK_SPEED=1.0
export LAZY_READER_OPENROUTER_SPEED=1.3
export LAZY_READER_OPENROUTER_RESPONSE_FORMAT=auto
export LAZY_READER_STREAM_PLAYBACK=1
```

`LAZY_READER_STREAM_PLAYBACK` is a runtime environment toggle today, not a Nix
module option.

Priority is env var first, then Nix option (`LAZY_READER_SPEED` / `services.lazy-reader.speed`, `LAZY_READER_PLAYBACK_SPEED` / `services.lazy-reader.playbackSpeed`).

Compatibility note: older setups may remember `LAZY_READER_SPEED` feeling faster because playback was also accelerated. To restore that exact behavior, set `playbackSpeed` (or `LAZY_READER_PLAYBACK_SPEED`) equal to `speed`.

Long AI-generated outputs (narrate, explain, summarize, solve, ask, teach) are also spoken in bounded Piper chunks now, using `services.lazy-reader.generatedSpeechChunkMaxChars` (default `1400`). This is meant to reduce fast/garbled synthesis on longer technical passages, at the cost of small extra pauses between long sections.

### Narrate mode (selected text → faithful spoken rendering → speech)

Narrate mode is for selections that are awkward to hear verbatim: technical documentation, source code, configs, logs, shell commands, or mixed prose + code. Unlike plain read mode, narrate turns the selection into a **faithful spoken rendering** before Piper reads it aloud. Unlike explain mode, it is not supposed to invent teaching context or broad clarifications. Unlike summarize mode, it should preserve the original order, identifiers, values, and technical details rather than aggressively compressing them. Unlike ask mode, it does not prompt for a follow-up question.

Narrate mode is disabled until you configure a narrator command.

The command must:

- read selected text from stdin,
- print a spoken-style narration to stdout.

Example with the bundled OpenRouter helper:

```nix
services.lazy-reader = {
  enableNarrateInGnome = true;
  gnomeNarrateShortcut = "<Super>e";  # default
  generatedSpeechChunkMaxChars = 1400;
  narrateInputMaxChars = 4800;
  narrateMaxChars = 2400;
  narrateCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/narrate-openrouter.sh;
};
```

The bundled `scripts/narrate-openrouter.sh` helper is meant for docs/code-heavy selections: it tries to stay close to the source text, keep identifiers and exact values intact, and only smooth the content enough to make it listenable over TTS. For code or config, it should describe what is visibly present rather than freely explaining from background knowledge.

Optional runtime tuning vars for the bundled narrate script:

- `LAZY_READER_NARRATE_MODEL` (default: `x-ai/grok-4.1-fast`)
- `LAZY_READER_NARRATE_MAX_TOKENS` (default: `2400`)
- `LAZY_READER_NARRATE_TEMPERATURE` (default: `0.12`)
- `LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS` (default: `1400`)
- `LAZY_READER_NARRATE_INPUT_MAX_CHARS` (default: `4800`)
- `LAZY_READER_OPENROUTER_API_KEY` (required unless `services.lazy-reader.openRouterApiKeyFile` is set)

Default narrate hotkey in GNOME is `services.lazy-reader.gnomeNarrateShortcut = "<Super>e"`. No extra GNOME conflict-clearing option is needed for that default. Older configs may still mention `clearDefaultSuperNInGnome`; it is now a deprecated no-op for backward compatibility.

### Explain mode (selected snippet → clarification → speech)

Explain mode is disabled until you configure an explainer command. It is best for shorter snippets where you want a quick teaching-style clarification rather than a broad passage summary.

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
  explainCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/explain-openrouter.sh;
};
```

Optional runtime tuning vars for the OpenRouter script:

- `LAZY_READER_OPENROUTER_API_KEY` (required unless `services.lazy-reader.openRouterApiKeyFile` is set)

Current defaults in `scripts/explain-openrouter.sh` are fixed to:

- model: `x-ai/grok-4.1-fast`
- max tokens: `1200`
- temperature: `0.1`

If you want these configurable via environment variables, edit that script.

Default explain hotkey in GNOME is `services.lazy-reader.gnomeExplainShortcut = "<Super>a"` (GNOME app grid is cleared automatically via `clearDefaultSuperAInGnome = true`).

### Summarize mode (selected passage → spoken summary → speech)

Summarize mode is disabled until you configure a summarizer command. It is distinct from explain mode: summarize compresses longer passages, while explain teaches or clarifies shorter snippets.

The command must:

- read selected text from stdin,
- print the spoken summary to stdout.

Example with a local Ollama model:

```nix
services.lazy-reader = {
  enableSummarizeInGnome = true;
  gnomeSummarizeShortcut = "<Super>w";  # default
  summarizeMaxChars = 3200;
  summarizeInputMaxChars = 6000;
  summarizeCommand = ''
    ollama run qwen2.5:7b "Summarize this passage for listening aloud:\n$(cat)"
  '';
};
```

Example with the bundled OpenRouter script:

```nix
services.lazy-reader = {
  enableSummarizeInGnome = true;
  gnomeSummarizeShortcut = "<Super>w";
  summarizeMaxChars = 3200; # larger spoken-output budget than explain
  summarizeInputMaxChars = 6000; # larger default input budget than explain
  summarizeCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/summarize-openrouter.sh;
};
```

Optional runtime tuning vars for the bundled summarize script:

- `LAZY_READER_SUMMARIZE_MODEL` (default: `openai/gpt-5.4-mini`)
- `LAZY_READER_SUMMARIZE_MAX_TOKENS` (default: `3200`)
- `LAZY_READER_SUMMARIZE_TEMPERATURE` (default: `0.12`)
- `LAZY_READER_OPENROUTER_API_KEY` (required unless `services.lazy-reader.openRouterApiKeyFile` is set)

By default, summarize mode accepts up to `services.lazy-reader.summarizeInputMaxChars = 6000` selected characters before backend processing, which is intentionally larger than the typical explain flow. The spoken summary is still capped separately by `services.lazy-reader.summarizeMaxChars`, which defaults to `3200`.

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
  problemSolverCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/problem-solver-openrouter.sh;
};
```

Optional runtime tuning vars for the OpenRouter solver script:

- `LAZY_READER_PROBLEM_SOLVER_MODEL` (default: `x-ai/grok-4.1-fast`)
- `LAZY_READER_PROBLEM_SOLVER_MAX_TOKENS` (default: `1600`)
- `LAZY_READER_PROBLEM_SOLVER_TEMPERATURE` (default: `0.12`)
- `LAZY_READER_OPENROUTER_API_KEY` (required unless `services.lazy-reader.openRouterApiKeyFile` is set)

Default solver hotkey in GNOME is `services.lazy-reader.gnomeProblemSolverShortcut = "<Super>q"`.
When using `Super+Q`, the module can remove GNOME's default close-window conflict automatically via `clearDefaultSuperQInGnome = true`.

### Ask mode (selected text + typed question → answer → speech)

Ask mode lets you highlight a passage, press `Super+Shift+A`, type a free-form question in a small GNOME dialog, and hear the answer spoken aloud. It is distinct from the other assistant modes: explain clarifies shorter snippets, summarize compresses longer passages, and ask answers your specific question.

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

- `LAZY_READER_OPENROUTER_API_KEY` (required unless `services.lazy-reader.openRouterApiKeyFile` is set)

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

### Teach mode (selected book page → ELI5 explanation → speech)

Teach mode is for programming book pages. Select a page of text, press `Super+P`, and hear it explained in plain language: what the concept is, why it matters, how it works simply, and the key takeaway. It uses an ELI5 (explain like I'm new) approach with analogies where helpful — distinct from explain (for short snippets), summarize (compression), and narrate (faithful rendering).

Teach mode is disabled until you configure a teach command.

```nix
services.lazy-reader = {
  enable = true;
  enableTeachInGnome = true;
  gnomeTeachShortcut = "<Super>p";  # default
  teachInputMaxChars = 5000;
  teachCommand = ''
    # Your command that reads a book page on stdin
    # and prints a plain ELI5 explanation to stdout
  '';
};
```

With the bundled OpenRouter helper:

```nix
services.lazy-reader = {
  enable = true;
  enableTeachInGnome = true;
  gnomeTeachShortcut = "<Super>p";  # default
  teachMaxChars = 3000;
  teachInputMaxChars = 5000;
  teachCommand = builtins.readFile /path/to/lazy-reader-nix/scripts/teach-openrouter.sh;
};
```

Optional runtime tuning vars for the OpenRouter teach script:

- `LAZY_READER_TEACH_MODEL` — override the model (default: `x-ai/grok-4.1-fast`)
- `LAZY_READER_TEACH_MAX_TOKENS` — override max tokens (default: `1800`)
- `LAZY_READER_TEACH_TEMPERATURE` — override temperature (default: `0.2`)

Default teach hotkey in GNOME is `services.lazy-reader.gnomeTeachShortcut = "<Super>p"`. The module automatically clears the GNOME `Super+P` display-switch binding when `clearDefaultSuperPInGnome = true` (the default) and the shortcut is `<Super>p`.

**Command contract summary:**

| Channel | Content |
|---------|---------|
| stdin | Selected book text (trimmed to `teachInputMaxChars`) |
| stdout | ELI5 explanation (trimmed to `teachMaxChars`, then spoken) |

Quick manual test:

```bash
wl-copy --primary "A closure is a function that captures variables from its surrounding scope..."
LAZY_READER_TEACH_CMD='printf "Think of a closure like a backpack."' lazy-reader teach
```

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

# Narrate binding (when enableNarrateInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-narrate/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-narrate/ command

# Summarize binding (when enableSummarizeInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-summarize/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-summarize/ command

# Problem-solver binding (when enableProblemSolverInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-problem-solver/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-problem-solver/ command

# Ask binding (when enableAskInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-ask/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-ask/ command

# Teach binding (when enableTeachInGnome = true)
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-teach/ binding
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-teach/ command
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

If you changed shell env vars or narrate/explain/summarize/solver/ask/teach command behavior, run that restart command so GNOME re-reads the command binding.

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
- Notifications are transient and Lazy Reader replaces the previous popup, so mode messages auto-dismiss after about 1 second.
- No audio: switch player:
  ```nix
  services.lazy-reader.audioPlayer = "ffplay";
  ```
- Selection empty in some apps: select text then copy once, script will use clipboard fallback.

## Running the tests

```bash
bash tests/run.sh
```

This is the primary repository validation command. It runs two suites:

1. **Syntax checks** (`tests/syntax.sh`) — `bash -n` on every shell script and `nix-instantiate --parse` on every Nix file.
2. **Bats unit/integration tests** (`tests/bats/`) — covers `trim_text`, `read_selection`, `is_running`, `cleanup_stale_pid_file`, `validate_config`, `run_narrator`, `run_explainer`, `run_summarizer`, `run_problem_solver`, `run_asker`, `run_teacher`, the bundled `narrate-openrouter.sh` helper contract, and the main dispatch logic.

`bats` is pulled in automatically via `nix-shell -p bats` if not already on `PATH`.

Focused syntax-only checks are also available:

```bash
bash -n scripts/lazy-reader.sh
for f in scripts/lib/*.sh; do bash -n "$f"; done
for f in lazy-reader.nix default.nix nix/*.nix; do nix-instantiate --parse "$f"; done
```

## License

MIT. See `LICENSE`.

## Contributing

See `CONTRIBUTING.md`.

## Security

See `SECURITY.md` for private vulnerability reporting guidance.
