# Security Policy

## Supported scope

This repository contains a local NixOS module and shell script for user-triggered text-to-speech.

Security fixes are made against the current default branch. Older revisions may
not receive fixes.

## Reporting a vulnerability

Please do not open a public issue for sensitive vulnerabilities.

Instead, use GitHub's private vulnerability reporting form from this
repository's Security tab. If private reporting is not enabled, contact the
repository owner through their GitHub profile and do not include exploit
details in a public issue.

Include:

- A clear description of the issue
- Reproduction steps
- Potential impact
- Any suggested mitigation

## Security notes for users

- Keep your API key in environment variables, not in tracked files.
- The bundled `*-openrouter.sh` helper scripts send selected text to OpenRouter; do not use them for sensitive text unless you accept that trade-off.
- Review local shell startup files if you use `source ~/.zshrc` in keybindings.
- Treat selected clipboard/primary text as sensitive user data.
