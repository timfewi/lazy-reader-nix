{
  cfg,
  pkgs,
  lib,
  ...
}:
let
  resolvedModel =
    if cfg.modelUrl != null then
      pkgs.fetchurl {
        url = cfg.modelUrl;
        sha256 = cfg.modelSha256;
      }
    else
      cfg.model;

  resolvedModelConfig =
    if cfg.modelConfigUrl != null then
      pkgs.fetchurl {
        url = cfg.modelConfigUrl;
        sha256 = cfg.modelConfigSha256;
      }
    else
      cfg.modelConfig;
in
pkgs.writeShellApplication {
  name = "lazy-reader";
  # SC2016: $(cat) inside single-quoted LAZY_READER_*_CMD value is intentional —
  # the value is a shell command string executed later via `bash -c`, not expanded at assignment.
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = with pkgs; [
    alsa-utils
    bash
    coreutils
    curl
    ffmpeg
    gawk
    jq
    libnotify
    mpv
    piper-tts
    procps
    wl-clipboard
    zenity
  ];
  text = ''
    export LAZY_READER_MODEL="${resolvedModel}"
    export LAZY_READER_MODEL_CONFIG="${resolvedModelConfig}"
    export LAZY_READER_PIPER_DATA_DIR="${cfg.piperDataDir}"
    export LAZY_READER_SPEAKER="${toString cfg.speaker}"
    export LAZY_READER_MAX_CHARS="${toString cfg.maxChars}"
    export LAZY_READER_PLAYER="${cfg.audioPlayer}"
    export LAZY_READER_SPEED="''${LAZY_READER_SPEED:-${toString cfg.speed}}"
    export LAZY_READER_PLAYBACK_SPEED="''${LAZY_READER_PLAYBACK_SPEED:-${toString cfg.playbackSpeed}}"
    export LAZY_READER_OPENROUTER_SPEED="''${LAZY_READER_OPENROUTER_SPEED:-${
      lib.optionalString (cfg.openRouterSpeed != null) (toString cfg.openRouterSpeed)
    }}"
    export LAZY_READER_OPENROUTER_RESPONSE_FORMAT="''${LAZY_READER_OPENROUTER_RESPONSE_FORMAT:-${cfg.openRouterResponseFormat}}"
    export LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS="''${LAZY_READER_GENERATED_SPEECH_CHUNK_MAX_CHARS:-${toString cfg.generatedSpeechChunkMaxChars}}"
    export LAZY_READER_OPENROUTER_API_KEY_FILE="''${LAZY_READER_OPENROUTER_API_KEY_FILE:-${cfg.openRouterApiKeyFile or ""}}"
    export LAZY_READER_TTS_PROVIDER="${cfg.ttsProvider}"
    export LAZY_READER_TTS_MODEL="${cfg.ttsModel}"
    export LAZY_READER_TTS_VOICE="${cfg.ttsVoice}"
    if [[ -z "''${LAZY_READER_NARRATE_CMD:-}" ]]; then
      export LAZY_READER_NARRATE_CMD=${lib.escapeShellArg cfg.narrateCommand}
    fi
    export LAZY_READER_NARRATE_INPUT_MAX_CHARS="''${LAZY_READER_NARRATE_INPUT_MAX_CHARS:-${toString cfg.narrateInputMaxChars}}"
    export LAZY_READER_NARRATE_MAX_CHARS="''${LAZY_READER_NARRATE_MAX_CHARS:-${toString cfg.narrateMaxChars}}"
    if [[ -z "''${LAZY_READER_EXPLAIN_CMD:-}" ]]; then
      export LAZY_READER_EXPLAIN_CMD=${lib.escapeShellArg cfg.explainCommand}
    fi
    export LAZY_READER_EXPLAIN_MAX_CHARS="''${LAZY_READER_EXPLAIN_MAX_CHARS:-${toString cfg.explainMaxChars}}"
    if [[ -z "''${LAZY_READER_SUMMARIZE_CMD:-}" ]]; then
      export LAZY_READER_SUMMARIZE_CMD=${lib.escapeShellArg cfg.summarizeCommand}
    fi
    export LAZY_READER_SUMMARIZE_MAX_CHARS="''${LAZY_READER_SUMMARIZE_MAX_CHARS:-${toString cfg.summarizeMaxChars}}"
    export LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS="''${LAZY_READER_SUMMARIZE_INPUT_MAX_CHARS:-${toString cfg.summarizeInputMaxChars}}"
    if [[ -z "''${LAZY_READER_PROBLEM_SOLVER_CMD:-}" ]]; then
      export LAZY_READER_PROBLEM_SOLVER_CMD=${lib.escapeShellArg cfg.problemSolverCommand}
    fi
    export LAZY_READER_PROBLEM_SOLVER_MAX_CHARS="''${LAZY_READER_PROBLEM_SOLVER_MAX_CHARS:-${toString cfg.problemSolverMaxChars}}"
    if [[ -z "''${LAZY_READER_ASK_CMD:-}" ]]; then
      export LAZY_READER_ASK_CMD=${lib.escapeShellArg cfg.askCommand}
    fi
    export LAZY_READER_ASK_MAX_CHARS="''${LAZY_READER_ASK_MAX_CHARS:-${toString cfg.askMaxChars}}"
    if [[ -z "''${LAZY_READER_TEACH_CMD:-}" ]]; then
      export LAZY_READER_TEACH_CMD=${lib.escapeShellArg cfg.teachCommand}
    fi
    export LAZY_READER_TEACH_MAX_CHARS="''${LAZY_READER_TEACH_MAX_CHARS:-${toString cfg.teachMaxChars}}"
    export LAZY_READER_TEACH_INPUT_MAX_CHARS="''${LAZY_READER_TEACH_INPUT_MAX_CHARS:-${toString cfg.teachInputMaxChars}}"
    if [[ -z "''${LAZY_READER_MASTER_CMD:-}" ]]; then
      export LAZY_READER_MASTER_CMD=${lib.escapeShellArg cfg.masterCommand}
    fi
    export LAZY_READER_MASTER_MAX_CHARS="''${LAZY_READER_MASTER_MAX_CHARS:-${toString cfg.masterMaxChars}}"
    export LAZY_READER_MASTER_INPUT_MAX_CHARS="''${LAZY_READER_MASTER_INPUT_MAX_CHARS:-${toString cfg.masterInputMaxChars}}"
    exec ${pkgs.bash}/bin/bash ${../scripts}/lazy-reader.sh "$@"
  '';
}
