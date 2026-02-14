# Contributing

Thanks for helping improve lazy-reader-nix.

## Local workflow

1. Edit module/script/docs.
2. Validate shell script syntax:

   ```bash
   bash -n scripts/lazy-reader.sh
   ```

3. Validate Nix parses:

   ```bash
   nix-instantiate --parse lazy-reader.nix
   ```

4. Rebuild and test on NixOS:

   ```bash
   sudo nixos-rebuild switch
   lazy-reader status
   ```

## Pull requests

- Keep changes focused and minimal.
- Update `README.md` when behavior or options change.
- Do not commit secrets or machine-specific paths.

## Reporting issues

Please include:

- NixOS version
- Desktop session (GNOME/Wayland expected)
- Relevant logs (`systemctl --user status lazy-reader-bind-gnome.service`)
- Exact repro steps
