#!/usr/bin/env bash
set -euo pipefail

# Install the plugins and CLI helpers into the current user's Omarchy session.
# Idempotent: re-running updates the files in place.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$PLUGINS" "$BIN_DIR"

cp -a "$ROOT/plugins/elinchi.wallpaper-editor" "$PLUGINS/"
cp -a "$ROOT/plugins/elinchi.background-per-monitor" "$PLUGINS/"

install -m 755 "$ROOT/bin/omarchy-per-monitor-bg" "$BIN_DIR/omarchy-per-monitor-bg"
install -m 755 "$ROOT/bin/omarchy-monitor-control" "$BIN_DIR/omarchy-monitor-control"

# File the existing single-file config under the active theme so nothing is
# lost on the next theme change. Safe to run repeatedly.
"$BIN_DIR/omarchy-per-monitor-bg" migrate || true

cat <<'MSG'

Installed.

Next steps:
  1. Add both ids to ~/.config/omarchy/shell.json "plugins" if they are missing:
       { "id": "elinchi.background-per-monitor" }
       { "id": "elinchi.wallpaper-editor" }
     and keep "omarchy.background" in "disabledPlugins".
  2. Restart the shell:  omarchy-restart-shell
  3. Open the editor from the Omarchy menu, or:
       omarchy-shell shell summon elinchi.wallpaper-editor '{}'

Run the tests with:
  node --test plugins/elinchi.background-per-monitor/test/
  node --test plugins/elinchi.wallpaper-editor/test/
MSG
