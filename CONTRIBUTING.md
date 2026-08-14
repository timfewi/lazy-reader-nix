# Contributing

Thanks for helping improve lazy-reader-nix.

## Local workflow

1. Edit module/script/docs.
2. Run the full validation suite:

   ```bash
   bash tests/run.sh
   ```

3. If you only need a quick targeted check while iterating, use focused syntax commands:

   ```bash
   bash -n scripts/lazy-reader.sh
   for f in scripts/lib/*.sh; do bash -n "$f"; done
   for f in lazy-reader.nix default.nix nix/*.nix; do nix-instantiate --parse "$f"; done
   ```

4. Test a NixOS integration manually only when you explicitly intend to
   activate your own configuration. This repository's automated checks do not
   rebuild or switch a system.

## Pull requests

- Keep changes focused and minimal.
- Update `README.md` and relevant documentation when behavior, options, or
  contributor workflow changes.
- Do not commit secrets or machine-specific paths.

## Reporting issues

Please include:

- NixOS version
- Desktop session (GNOME/Wayland expected)
- Relevant logs (`systemctl --user status lazy-reader-bind-gnome.service`)
- Exact repro steps

For security-sensitive reports, follow `SECURITY.md` instead of opening an
issue.
