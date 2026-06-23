{
  cfg,
  pkgs,
  lib,
  lazyReaderScript,
}:
let
  # Generate shell code to register a single GNOME custom keybinding.
  mkBinding =
    {
      name,
      commandSuffix,
      shortcut,
      clearShortcut ? null,
      clearCheck ? shortcut,
      preHook ? "",
    }:
    let
      escapedName = lib.escapeShellArg name;
      keyPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader${
        lib.optionalString (commandSuffix != "") "-${commandSuffix}"
      }/";
      fullCommand = "${pkgs.bash}/bin/bash -c \"exec ${lazyReaderScript}/bin/lazy-reader ${commandSuffix}\"";
    in
    ''
        ${preHook}

        ${lib.optionalString (clearShortcut != null) ''
          if [[ "${shortcut}" == "${clearCheck}" ]]; then
            gsettings set ${clearShortcut} "[]" || true
          fi
        ''}

        current="$(${pkgs.glib.bin}/bin/gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"

        updated="$(${pkgs.python3}/bin/python3 - "$current" '${keyPath}' <<'PY'
      import ast, sys
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

        ${pkgs.glib.bin}/bin/gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated"
        ${pkgs.glib.bin}/bin/gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${keyPath}" name ${escapedName}
        ${pkgs.glib.bin}/bin/gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${keyPath}" command '${fullCommand}'
        ${pkgs.glib.bin}/bin/gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"${keyPath}" binding "${shortcut}"
    '';

  # Remove a single shortcut value from a gsettings array (e.g. <Super>q from window close).
  removeFromArray =
    { gsettingsPath, value }:
    ''
        current="$(${pkgs.glib.bin}/bin/gsettings get ${gsettingsPath})"
        updated="$(${pkgs.python3}/bin/python3 - "$current" "${value}" <<'PY'
      import ast, sys
      raw = sys.argv[1].strip()
      if raw.startswith("@as"):
          raw = "[]"
      try:
          data = ast.literal_eval(raw)
      except Exception:
          data = []
      data = [item for item in data if item != sys.argv[2]]
      print("[" + ", ".join(repr(item) for item in data) + "]")
      PY
        )"
        ${pkgs.glib.bin}/bin/gsettings set ${gsettingsPath} "$updated" || true
    '';
in
pkgs.writeShellApplication {
  name = "lazy-reader-bind-gnome";
  excludeShellChecks = [ "SC2050" ];
  runtimeInputs = with pkgs; [
    coreutils
    glib
    python3
  ];
  text = ''
    if ! gsettings get org.gnome.desktop.interface color-scheme >/dev/null 2>&1; then
      exit 0
    fi

    ${mkBinding {
      name = "Lazy Reader";
      commandSuffix = "";
      shortcut = cfg.gnomeShortcut;
      clearShortcut = lib.optionalString cfg.clearDefaultSuperSInGnome "org.gnome.shell.keybindings toggle-quick-settings";
      clearCheck = "<Super>s";
    }}

    ${lib.optionalString cfg.enableNarrateInGnome (mkBinding {
      name = "Lazy Reader Narrate";
      commandSuffix = "narrate";
      shortcut = cfg.gnomeNarrateShortcut;
    })}

    ${lib.optionalString cfg.enableExplainInGnome (mkBinding {
      name = "Lazy Reader Explain";
      commandSuffix = "explain";
      shortcut = cfg.gnomeExplainShortcut;
      clearShortcut = lib.optionalString cfg.clearDefaultSuperAInGnome "org.gnome.shell.keybindings toggle-application-view";
      clearCheck = "<Super>a";
    })}

    ${lib.optionalString cfg.enableSummarizeInGnome (mkBinding {
      name = "Lazy Reader Summarize";
      commandSuffix = "summarize";
      shortcut = cfg.gnomeSummarizeShortcut;
    })}

    ${lib.optionalString cfg.enableProblemSolverInGnome (mkBinding {
      name = "Lazy Reader Solve";
      commandSuffix = "solve";
      shortcut = cfg.gnomeProblemSolverShortcut;
      preHook = lib.optionalString cfg.clearDefaultSuperQInGnome (removeFromArray {
        gsettingsPath = "org.gnome.desktop.wm.keybindings close";
        value = "<Super>q";
      });
    })}

    ${lib.optionalString cfg.enableAskInGnome (mkBinding {
      name = "Lazy Reader Ask";
      commandSuffix = "ask";
      shortcut = cfg.gnomeAskShortcut;
    })}

    ${lib.optionalString cfg.enableTeachInGnome (mkBinding {
      name = "Lazy Reader Teach";
      commandSuffix = "teach";
      shortcut = cfg.gnomeTeachShortcut;
    })}

    ${lib.optionalString cfg.enableMasterInGnome (mkBinding {
      name = "Lazy Reader Master";
      commandSuffix = "master";
      shortcut = cfg.gnomeMasterShortcut;
      preHook = lib.optionalString cfg.clearDefaultSuperMInGnome (removeFromArray {
        gsettingsPath = "org.gnome.desktop.wm.keybindings switch-to-workspace-last";
        value = "<Super>m";
      });
    })}

    ${lib.optionalString cfg.enableVisionInGnome (mkBinding {
      name = "Lazy Reader Vision";
      commandSuffix = "vision";
      shortcut = cfg.gnomeVisionShortcut;
    })}
  '';
}
