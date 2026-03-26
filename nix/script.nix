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
  # SC2016: $(cat) inside single-quoted LAZY_READER_EXPLAIN_CMD default is intentional —
  # the value is a shell command string executed later via bash -lc, not expanded at assignment.
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = with pkgs; [
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
    export LAZY_READER_EXPLAIN_CMD=''${LAZY_READER_EXPLAIN_CMD:-${lib.escapeShellArg cfg.explainCommand}}
    export LAZY_READER_EXPLAIN_MAX_CHARS="''${LAZY_READER_EXPLAIN_MAX_CHARS:-${toString cfg.explainMaxChars}}"
    export LAZY_READER_PROBLEM_SOLVER_CMD=''${LAZY_READER_PROBLEM_SOLVER_CMD:-${lib.escapeShellArg cfg.problemSolverCommand}}
    export LAZY_READER_PROBLEM_SOLVER_MAX_CHARS="''${LAZY_READER_PROBLEM_SOLVER_MAX_CHARS:-${toString cfg.problemSolverMaxChars}}"
    export LAZY_READER_ASK_CMD=''${LAZY_READER_ASK_CMD:-${lib.escapeShellArg cfg.askCommand}}
    export LAZY_READER_ASK_MAX_CHARS="''${LAZY_READER_ASK_MAX_CHARS:-${toString cfg.askMaxChars}}"
    exec ${pkgs.bash}/bin/bash ${../scripts}/lazy-reader.sh "$@"
  '';
}
