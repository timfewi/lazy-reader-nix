#!/usr/bin/env bats

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

@test "nix options: narrate GNOME shortcut defaults to Super+E" {
  run grep -n 'default = "<Super>e";' "${REPO_ROOT}/nix/options.nix"
  [ "$status" -eq 0 ]
}

@test "GNOME bind script: narrate binding does not clear a GNOME Super+N shortcut" {
  run grep -n 'focus-active-notification' "${REPO_ROOT}/nix/bind-script.nix"
  [ "$status" -ne 0 ]
}
