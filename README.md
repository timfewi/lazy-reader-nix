# lazy-reader-nix

Reads currently selected text out loud with GROQ Text-to-Speech when you press `Super+S` (GNOME Wayland).

## What this repo provides

- `lazy-reader.nix`: NixOS module (`services.lazy-reader`) 
- `scripts/lazy-reader.sh`: runtime script that:
  - gets selected text from Wayland selection (`wl-paste --primary`) with clipboard fallback,
  - calls GROQ TTS API (`/openai/v1/audio/speech`),
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
    speed = 1.4;
    playbackSpeed = 1.4;

    # Optional
    # autoBindInGnome = true;
    # model = "canopylabs/orpheus-v1-english";
    # voice = "troy";
    # audioPlayer = "mpv";
  };
}
```

If you clone this repository and keep `configuration.nix` in the same repo tree, you can also import `./lazy-reader.nix`.

Apply changes:

```bash
sudo nixos-rebuild switch
```

## Set API key securely

The module expects `LAZY_READER_GROQ_API_KEY` in your user session environment by default.

Example (temporary for current shell/session):

```bash
export LAZY_READER_GROQ_API_KEY='your-real-key'
```

For persistent user-level env on NixOS, set it via your preferred secret strategy (e.g. user environment manager, systemd user environment file, or an encrypted secret flow). Do **not** hardcode API keys in Nix files.

This module binds the shortcut command through `zsh -lc`, so exports from your `~/.zshrc` are loaded when pressing `Super+S`.

You can change env var name:

```nix
services.lazy-reader.apiKeyEnvVar = "MY_GROQ_KEY";
```

## Behavior

1. Highlight text with mouse in any window.
2. Press `Super+S` to start reading.
3. Press `Super+S` again while reading to stop immediately.

If no text is selected, it shows a notification.

## Quick test (without hotkey)

Run this first to verify API + audio work:

```bash
export LAZY_READER_GROQ_API_KEY='your-real-key'
wl-copy --primary "Hello, this is a lazy reader test."
lazy-reader
```

Manual controls:

```bash
lazy-reader start
lazy-reader stop
lazy-reader status
```

If this works, your script is fine and only keybinding setup remains.

## Make reading faster

Set speed in Nix and rebuild:

```nix
services.lazy-reader.speed = 1.3;
services.lazy-reader.playbackSpeed = 1.4;
```

`1.0` is normal speed, `1.3` / `1.4` are faster.

Default is now `1.4` if you do not set anything.

If the model still sounds slow, increase `playbackSpeed` (this is applied by local player and always takes effect).

Why both exist:
- `speed`: sent to GROQ TTS model (voice generation speed).
- `playbackSpeed`: local player speed multiplier (always audible).

You can also override at runtime (because shortcut runs through `zsh -lc`):

```bash
export LAZY_READER_SPEED=1.3
export LAZY_READER_PLAYBACK_SPEED=1.4
```

Priority is env var first, then Nix option (`LAZY_READER_SPEED` / `services.lazy-reader.speed`, and `LAZY_READER_PLAYBACK_SPEED` / `services.lazy-reader.playbackSpeed`).

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

If you changed your API key export in `~/.zshrc`, run that restart command so GNOME re-reads the command binding.

## Troubleshooting

- Error `requires terms acceptance` (HTTP 400):
  - Open https://console.groq.com/playground?model=canopylabs/orpheus-v1-english
  - Accept model terms with your org/admin account
  - Re-run `lazy-reader`
  - If your account uses a different approved TTS model, set it in Nix:
    ```nix
    services.lazy-reader.model = "your-approved-tts-model";
    ```

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
- `Missing API key` only on `Super+S` but works in terminal:
  - Confirm `~/.zshrc` includes: `export LAZY_READER_GROQ_API_KEY=...`
  - Rebuild + restart `lazy-reader-bind-gnome.service`.
- Missing notifications: ensure notification daemon is running in desktop session.
- No audio: switch player:
  ```nix
  services.lazy-reader.audioPlayer = "ffplay";
  ```
- Selection empty in some apps: select text then copy once, script will use clipboard fallback.

## License

MIT. See `LICENSE`.

## Contributing

See `CONTRIBUTING.md`.

## Security

See `SECURITY.md` for private vulnerability reporting guidance.
