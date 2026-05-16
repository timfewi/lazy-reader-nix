{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.lazy-reader;
  lazyReaderScript = import ./nix/script.nix { inherit cfg pkgs lib; };
  lazyReaderSetTtsScript = import ./nix/set-tts-script.nix { inherit pkgs; };
  lazyReaderBindScript = import ./nix/bind-script.nix { inherit cfg pkgs lib; };
in
{
  options.services.lazy-reader = import ./nix/options.nix { inherit lib; };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.modelUrl == null || cfg.modelSha256 != null;
        message = "services.lazy-reader.modelSha256 is required when services.lazy-reader.modelUrl is set.";
      }
      {
        assertion = cfg.modelConfigUrl == null || cfg.modelConfigSha256 != null;
        message = "services.lazy-reader.modelConfigSha256 is required when services.lazy-reader.modelConfigUrl is set.";
      }
    ];

    environment.systemPackages = [
      lazyReaderScript
      lazyReaderSetTtsScript
    ];

    systemd.user.services.lazy-reader-bind-gnome =
      import ./nix/service.nix { inherit lazyReaderBindScript lib cfg; };
  };
}
