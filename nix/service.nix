{ lazyReaderBindScript, lib, cfg }:
lib.mkIf cfg.autoBindInGnome {
  description = "Ensure GNOME Super+S binding exists for Lazy Reader";
  wantedBy = [ "graphical-session.target" ];
  after = [ "graphical-session.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${lazyReaderBindScript}/bin/lazy-reader-bind-gnome";
  };
}
