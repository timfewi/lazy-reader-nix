{ lib }:
{
  enable = lib.mkEnableOption "selected-text to speech reader with local Piper TTS";

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

  model = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/piper/en_US-lessac-medium.onnx";
    description = "Local Piper model path (.onnx).";
  };

  modelUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Optional Piper model URL (.onnx). When set, Nix fetches the model into the store and uses that path at runtime.";
  };

  modelSha256 = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Required sha256 for modelUrl.";
  };

  modelConfig = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Optional Piper model config path (.onnx.json). Leave empty to auto-detect.";
  };

  modelConfigUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Optional Piper model config URL (.onnx.json). When set, Nix fetches it into the store and uses that path at runtime.";
  };

  modelConfigSha256 = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Required sha256 for modelConfigUrl.";
  };

  piperDataDir = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Optional Piper data directory for voice/model lookup.";
  };

  speaker = lib.mkOption {
    type = lib.types.addCheck lib.types.int (value: value >= 0);
    default = 0;
    description = "Speaker ID for multi-speaker Piper models.";
  };

  audioPlayer = lib.mkOption {
    type = lib.types.enum [
      "mpv"
      "ffplay"
    ];
    default = "mpv";
    description = "Local player used to play generated speech audio.";
  };

  maxChars = lib.mkOption {
    type = lib.types.ints.positive;
    default = 2400;
    description = "Maximum selected characters sent to Piper TTS.";
  };

  speed = lib.mkOption {
    type = lib.types.addCheck lib.types.float (value: value >= 0.25 && value <= 4.0);
    default = 1.4;
    description = "Speech speed multiplier (0.25 to 4.0) used for both Piper synthesis and local playback.";
  };

  explainCommand = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Shell command that receives selected text on stdin and prints a human-readable explanation to stdout. Leave empty to disable explain mode.";
  };

  explainMaxChars = lib.mkOption {
    type = lib.types.ints.positive;
    default = 2400;
     description = "Maximum characters of explainCommand output passed to TTS.";
  };

  enableExplainInGnome = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Register a second GNOME shortcut that runs lazy-reader explain.";
  };

  gnomeExplainShortcut = lib.mkOption {
    type = lib.types.str;
    default = "<Super>a";
    description = "GNOME keybinding string used to trigger explain mode.";
  };

  clearDefaultSuperAInGnome = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Clear GNOME default Super+A binding (toggle-application-view / app grid) to avoid shortcut conflict when gnomeExplainShortcut is <Super>a.";
  };

  summarizeCommand = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = ''
      Shell command that receives selected text on stdin and prints a concise
      spoken summary to stdout. Leave empty to disable summarize mode.
    '';
  };

  summarizeMaxChars = lib.mkOption {
    type = lib.types.ints.positive;
    default = 3200;
    description = "Maximum characters of summarizeCommand output passed to TTS.";
  };

  summarizeInputMaxChars = lib.mkOption {
    type = lib.types.ints.positive;
    default = 6000;
    description = "Maximum selected characters passed to summarizeCommand before backend processing.";
  };

  enableSummarizeInGnome = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Register an additional GNOME shortcut that runs lazy-reader summarize.";
  };

  gnomeSummarizeShortcut = lib.mkOption {
    type = lib.types.str;
    default = "<Super>w";
    description = "GNOME keybinding string used to trigger summarize mode.";
  };

  problemSolverCommand = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Shell command that receives selected text on stdin and prints a concise solution/answer to stdout. Leave empty to disable problem-solver mode.";
  };

  problemSolverMaxChars = lib.mkOption {
    type = lib.types.ints.positive;
    default = 2400;
    description = "Maximum selected characters passed to problemSolverCommand.";
  };

  enableProblemSolverInGnome = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Register an additional GNOME shortcut that runs lazy-reader solve.";
  };

  gnomeProblemSolverShortcut = lib.mkOption {
    type = lib.types.str;
    default = "<Super>q";
    description = "GNOME keybinding string used to trigger problem-solver mode.";
  };

  clearDefaultSuperQInGnome = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Clear Super+Q from GNOME default window-close binding to avoid shortcut conflict when gnomeProblemSolverShortcut is <Super>q.";
  };

  askCommand = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = ''
      Shell command for ask mode. Receives selected text on stdin and the
      user's typed follow-up question in the LAZY_READER_ASK_QUESTION
      environment variable, then prints an answer to stdout. Leave empty to
      disable ask mode.
    '';
  };

  askMaxChars = lib.mkOption {
    type = lib.types.ints.positive;
    default = 2400;
    description = "Maximum characters of ask command output passed to TTS.";
  };

  enableAskInGnome = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Register an additional GNOME shortcut that runs lazy-reader ask.";
  };

  gnomeAskShortcut = lib.mkOption {
    type = lib.types.str;
    default = "<Super><Shift>a";
    description = "GNOME keybinding string used to trigger ask mode (default: Super+Shift+A).";
  };
}
