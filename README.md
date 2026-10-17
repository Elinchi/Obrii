# Obrii

**A simple Omarchy app to configure wallpapers and monitors properly.**
**Проста програма для Omarchy, щоб нормально налаштувати шпалери та монітори.**

Per-monitor wallpaper editor and display settings panel for
[Omarchy](https://github.com/basecamp/omarchy) on Hyprland/Quickshell.

Two Quickshell plugins plus a small CLI backend:

| Path | Purpose |
|---|---|
| `plugins/elinchi.background-per-monitor/` | Renders one wallpaper per monitor (Quickshell layer surface). Replaces the stock `omarchy.background` service. |
| `plugins/elinchi.wallpaper-editor/` | Panel UI: wallpaper tab (preview, drag, offsets, scaling, position) and displays tab (resolution, refresh rate, scale, orientation, layout). |
| `bin/omarchy-per-monitor-bg` | Stores the per-monitor config, picks files, keeps per-theme files in sync. |
| `bin/omarchy-monitor-control` | Applies display settings to `~/.config/hypr/monitors.lua` and verifies them through `hyprctl`. |

## Features

- **Per-theme settings.** Every theme owns `~/.config/omarchy/backgrounds-per-monitor/<theme>.json`.
  Switching themes snapshots the outgoing theme and restores the incoming one, so wallpapers,
  offsets, scaling mode and position survive a round trip.
- **One scaling implementation.** The editor preview and the real renderer call the same
  `WallpaperMath.js`, so they cannot drift apart. Covered by aspect-ratio tests.
- **Scaling modes:** `crop`, `fit`, `stretch`, `tile`; nine anchor positions; X/Y offsets.
- **Display validation.** After applying a mode, `hyprctl monitors -j` is re-read and the
  actual refresh rate is compared with the requested one. Mismatches are reported in the UI.
- **Bilingual UI.** English and Ukrainian, chosen from `LC_ALL` / `LANG` (see below).
- **Logging.** Structured `key=value` log at `~/.local/state/omarchy/wallpaper-editor.log`.

## Requirements

- Omarchy (Arch Linux) with Hyprland and Quickshell.
- The stock `omarchy.background` plugin disabled (this project replaces its service).
- `jq`, `hyprctl`, `python3` (already present on Omarchy).

## Install

```bash
git clone https://github.com/Elinchi/Obrii.git
cd Obrii
./install.sh
```

Then enable both plugins in `~/.config/omarchy/shell.json`:

```json
{
  "plugins": [
    { "id": "elinchi.background-per-monitor" },
    { "id": "elinchi.wallpaper-editor" }
  ],
  "disabledPlugins": ["omarchy.background"]
}
```

Restart the shell and open the editor from the Omarchy menu (or with
`omarchy-shell shell summon elinchi.wallpaper-editor '{}'`).

## Usage

- **Wallpaper tab**
  - Pick a monitor; drag the image or use the X/Y sliders. `↺` next to each slider resets it to 0.
  - `Scaling` chooses `crop`/`fit`/`stretch`/`tile`.
  - `Position` anchors `crop`/`fit` (center, edges, corners).
  - `Choose image…` sets a wallpaper for this monitor (stored per theme).
  - `Change theme…` opens Omarchy's theme picker; the editor stays open.
  - `Reset for monitor` drops the whole per-monitor entry (wallpaper + geometry).
- **Displays tab**
  - Drag displays on the map, choose resolution/refresh rate/scale/orientation.
  - `Apply` writes `monitors.lua`, reloads Hyprland and verifies the result.

## Per-theme storage

```
~/.config/omarchy/backgrounds-per-monitor.json      # active (read by the renderer)
~/.config/omarchy/backgrounds-per-monitor/
├── solitude.json
├── nord.json
└── ...
```

On a theme change the shell calls:

```bash
omarchy-per-monitor-bg sync-theme <new-theme-background>
```

which reads the outgoing theme from the active file's `theme` field, snapshots it, then
restores the incoming theme (or starts from the theme default when no file exists).
A monitor entry without a `wallpaper` key is valid: it applies scaling/position/offsets
to the theme's global wallpaper.

## Configuration fields

| Field | Values |
|---|---|
| `wallpaper` | absolute path; omitted means "use the theme wallpaper" |
| `source` | `theme` or `user` (where the wallpaper came from) |
| `mode` | `crop`, `fit`, `stretch`, `tile` |
| `position` | `center`, `top`, `bottom`, `left`, `right`, `top-left`, `top-right`, `bottom-left`, `bottom-right` |
| `offset_x`, `offset_y` | integer pixels |

## Language

The UI and CLI messages follow the session locale:

1. `WALLPAPER_EDITOR_LANG` (explicit override: `en` or `uk`)
2. `LC_ALL`
3. `LANG`
4. English

`uk*` / `ua*` selects Ukrainian, everything else English.

## Logging and debugging

```bash
tail -f ~/.local/state/omarchy/wallpaper-editor.log
```

Set `WALLPAPER_EDITOR_DEBUG=1` to also echo every log line to stderr:

```bash
WALLPAPER_EDITOR_DEBUG=1 omarchy-monitor-control apply DP-3 2560x1440@180.00 -35 1278 1 0
```

Log events include `apply-request`, `verify-ok`, `verify-failed`, `apply-ok`, `apply-error`,
`rollback`, `snapshot`, `restore`, `set-wallpaper`, `set-offsets`, `set-property`, and `ui`
for messages raised by the panel.

## Tests

```bash
node --test plugins/elinchi.background-per-monitor/test/
node --test plugins/elinchi.wallpaper-editor/test/
```

## Notes

- The renderer is Quickshell, not hyprpaper/swww/waypaper.
- `monitors.lua` is the single source of truth for display rules; `hyprctl keyword monitor`
  does not work with Omarchy's Lua config parser, so settings are applied with `hyprctl reload`
  and verified afterwards. A failed apply restores the previous file.

## License

MIT — see [LICENSE](LICENSE).
