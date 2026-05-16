{ pkgs }:
pkgs.writeShellApplication {
  name = "lazy-reader-set-tts";
  runtimeInputs = with pkgs; [
    coreutils
  ];
  text = builtins.readFile ../scripts/lazy-reader-set-tts;
}
