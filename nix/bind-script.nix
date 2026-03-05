{
  cfg,
  pkgs,
  lib,
}:
pkgs.writeShellApplication {
  name = "lazy-reader-bind-gnome";
  runtimeInputs = with pkgs; [
    coreutils
    glib
    python3
  ];
  text = ''
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

        ${lib.optionalString cfg.enableExplainInGnome ''
                explain_key_path='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-explain/'
                explain_command='${pkgs.zsh}/bin/zsh -lc "source ~/.zshrc 2>/dev/null || true; exec /run/current-system/sw/bin/lazy-reader explain"'
                explain_shortcut='${cfg.gnomeExplainShortcut}'

                ${lib.optionalString cfg.clearDefaultSuperAInGnome ''
                  if [[ "$explain_shortcut" == "<Super>a" ]]; then
                    gsettings set org.gnome.shell.keybindings toggle-application-view "[]" || true
                  fi
                ''}

                current_e="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"

                updated_e="$(python3 - "$current_e" "$explain_key_path" <<'PY'
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

                gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated_e"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$explain_key_path" name 'Lazy Reader Explain'
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$explain_key_path" command "$explain_command"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$explain_key_path" binding "$explain_shortcut"
        ''}

            ${lib.optionalString cfg.enableProblemSolverInGnome ''
                solver_key_path='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lazy-reader-problem-solver/'
                solver_command='${pkgs.zsh}/bin/zsh -lc "source ~/.zshrc 2>/dev/null || true; exec /run/current-system/sw/bin/lazy-reader solve"'
                solver_shortcut='${cfg.gnomeProblemSolverShortcut}'

                ${lib.optionalString cfg.clearDefaultSuperQInGnome ''
                          if [[ "$solver_shortcut" == "<Super>q" ]]; then
                            current_close="$(gsettings get org.gnome.desktop.wm.keybindings close)"
                            updated_close="$(python3 - "$current_close" <<'PY'
                  import ast
                  import sys

                  raw = sys.argv[1].strip()
                  if raw.startswith("@as"):
                      raw = "[]"

                  try:
                      data = ast.literal_eval(raw)
                  except Exception:
                      data = []

                  data = [item for item in data if item != "<Super>q"]
                  print("[" + ", ".join(repr(item) for item in data) + "]")
                  PY
                            )"
                            gsettings set org.gnome.desktop.wm.keybindings close "$updated_close" || true
                          fi
                ''}

                current_s="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"

                updated_s="$(python3 - "$current_s" "$solver_key_path" <<'PY'
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

                gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated_s"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$solver_key_path" name 'Lazy Reader Solve'
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$solver_key_path" command "$solver_command"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$solver_key_path" binding "$solver_shortcut"
            ''}
  '';
}
