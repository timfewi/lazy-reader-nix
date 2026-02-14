{ config, lib, pkgs, ... }:
let
  cfg = config.services.lazy-reader;

  lazyReaderScript = pkgs.writeShellApplication {
    name = "lazy-reader";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      curl
      ffmpeg
      glib
      jq
      libnotify
      mpv
      procps
      wl-clipboard
    ];
    text = ''
      export LAZY_READER_API_KEY_VAR="${cfg.apiKeyEnvVar}"
      export LAZY_READER_MODEL="${cfg.model}"
      export LAZY_READER_VOICE="${cfg.voice}"
      export LAZY_READER_RESPONSE_FORMAT="${cfg.responseFormat}"
      export LAZY_READER_MAX_CHARS="${toString cfg.maxChars}"
      export LAZY_READER_PLAYER="${cfg.audioPlayer}"
      export LAZY_READER_CONNECT_TIMEOUT="${toString cfg.connectTimeoutSeconds}"
      export LAZY_READER_TOTAL_TIMEOUT="${toString cfg.totalTimeoutSeconds}"
      export LAZY_READER_SPEED="''${LAZY_READER_SPEED:-${toString cfg.speed}}"
      export LAZY_READER_PLAYBACK_SPEED="''${LAZY_READER_PLAYBACK_SPEED:-${toString cfg.playbackSpeed}}"

      exec ${pkgs.bash}/bin/bash ${./scripts/lazy-reader.sh}
    '';
  };

  lazyReaderBindScript = pkgs.writeShellApplication {
    name = "lazy-reader-bind-gnome";
    runtimeInputs = with pkgs; [
      coreutils
      glib
      gnugrep
      gnused
      python3
    ];
    text = ''
      set -euo pipefail

      if ! gsettings get org.gnome.desktop.interface color-scheme >/dev/null 2>&1; then
        exit 0
      fi

      key_path='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader/'
      command='${pkgs.zsh}/bin/zsh -lc "source ~/.zshrc 2>/dev/null || true; exec /run/current-system/sw/bin/lazy-reader"'
      shortcut='${cfg.gnomeShortcut}'

      ${lib.optionalString cfg.clearDefaultSuperSInGnome ''
      if [[ "$shortcut" == "<Super>s" ]]; then
        gsettings set org.gnome.shell.keybindings toggle-quick-settings "[]" || true
      fi
      ''}

      current="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"

      updated="$(python3 - "$current" "$key_path" <<'PY'
import ast
import sys

raw = sys.argv[1].strip()
needle = sys.argv[2]

if raw.startswith("@as"):
    raw = "[]"

try:
    data = ast.literal_eval(raw)
except Exception:
    data = []

if needle not in data:
    data.append(needle)

print("[" + ", ".join(repr(item) for item in data) + "]")
PY
)"

      gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated"
      gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$key_path" name 'Lazy Reader'
      gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$key_path" command "$command"
      gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$key_path" binding "$shortcut"
    '';
  };
in {
  options.services.lazy-reader = {
    enable = lib.mkEnableOption "selected-text to speech reader with GROQ API";

    autoBindInGnome = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Configure GNOME custom shortcut automatically at login.";
    };

    gnomeShortcut = lib.mkOption {
      type = lib.types.str;
      default = "<Super>s";
      description = "GNOME keybinding string used to trigger Lazy Reader.";
    };

    clearDefaultSuperSInGnome = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Clear GNOME default Super+S binding (toggle-quick-settings) to avoid shortcut conflict.";
    };

    apiKeyEnvVar = lib.mkOption {
      type = lib.types.str;
      default = "LAZY_READER_GROQ_API_KEY";
      description = "Environment variable that contains the GROQ API key.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "canopylabs/orpheus-v1-english";
      description = "GROQ text-to-speech model.";
    };

    voice = lib.mkOption {
      type = lib.types.str;
      default = "troy";
      description = "Voice name for GROQ TTS.";
    };

    responseFormat = lib.mkOption {
      type = lib.types.enum [ "wav" "mp3" "flac" ];
      default = "wav";
      description = "Audio response format requested from GROQ.";
    };

    audioPlayer = lib.mkOption {
      type = lib.types.enum [ "mpv" "ffplay" ];
      default = "mpv";
      description = "Local player used to play generated speech audio.";
    };

    maxChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2400;
      description = "Maximum selected characters sent to the TTS API.";
    };

    connectTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Connection timeout for GROQ API request in seconds.";
    };

    totalTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 45;
      description = "Total timeout for GROQ API request in seconds.";
    };

    speed = lib.mkOption {
      type = lib.types.addCheck lib.types.float (value: value >= 0.25 && value <= 4.0);
      default = 1.4;
      description = "Speech speed sent to GROQ TTS (0.25 to 4.0). Example: 1.3 or 1.4.";
    };

    playbackSpeed = lib.mkOption {
      type = lib.types.addCheck lib.types.float (value: value >= 0.25 && value <= 4.0);
      default = 1.4;
      description = "Local audio playback speed multiplier (0.25 to 4.0). Use this if model speed sounds unchanged.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      lazyReaderScript
    ];

    systemd.user.services.lazy-reader-bind-gnome = lib.mkIf cfg.autoBindInGnome {
      description = "Ensure GNOME Super+S binding exists for Lazy Reader";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lazyReaderBindScript}/bin/lazy-reader-bind-gnome";
      };
    };
  };
}
