# Quickshell Bar — Architecture

Custom Hyprland shell replacing Waybar, built on [Quickshell](https://quickshell.outfoxxed.me),
with Omarchy quattro's `Ui/` component kit and panels adapted as modules.
Target: Fedora 42, Hyprland, matugen Material You theming, GNU Stow dotfiles.

## Design goals

1. **G1 — Omarchy-grade panels**: audio (volume + output picker + per-app mixer),
   network (scan/connect/signal), bluetooth (devices/battery), power (battery/profiles),
   monitor (brightness/scaling). Adapted from Omarchy's MIT-licensed code.
2. **G2 — Waybar parity, extensible**: workspaces, clock/calendar, tray now;
   media/visualizer/clipboard/cpu/network-speed later. Adding a module must be
   *one file + one registry line + one layout line*.
3. **G3 — Live theming**: matugen renders `colors.json` from the wallpaper;
   `Color.qml` watches it; every surface re-themes without restart.
4. **G4 — Dotfiles-native**: everything under `~/dotfiles/.config/quickshell`,
   stow-managed, scripts in `~/dotfiles/.local/share/bin` (already on PATH).
5. **G5 — Safe rollout**: Waybar stays installed; Quickshell is opt-in via
   `exec-once` and keybinds. Rollback = revert one line in `hyprland.conf`.

## Layers (strict, downward-only dependencies)

```
L6  shell.qml          ShellRoot: config IO, IPC, panel-instance registry
L5  Bar/Bar.qml        per-monitor host: sections, tooltip, popout, click targets
L4  Registry.qml       id -> component URL + metadata (THE extension point)
L3  Panels/*/          popup-capable bar modules (audio, network, ...)
    Bar/widgets/*.qml  plain bar modules (workspaces, tray)
L2  Services/          shared state singletons (none yet; reserved)
L1  Ui/                vendored component kit (Button, PanelSlider, KeyboardPanel...)
L0  Commons/           singletons: Color (matugen bridge), Style, Util, Border
```

Rules: `Ui/` and `Commons/` never import upward or know module ids.
`Bar/` knows the Registry, never concrete modules (instantiation is by URL).
Modules know `bar`/`shell` interfaces only.

## Contracts

### Bar API (provided by Bar/Bar.qml, consumed by Ui/ + all modules)

Properties: `vertical` (bool), `position` ("top"), `barSize` (int),
`fontFamily`, `foreground`, `barForeground`, `background`, `urgent`,
`foregroundAnimationEnabled`, `activePopout` (var), `clickTargets` (var list),
`shell` (nullable).

Functions:
- `run(command)` — exec detached via `sh -c`
- `showTooltip(item, text)` / `hideTooltip(item)` — hover-delayed tooltips
- `registerClickTarget(item)` / `unregisterClickTarget(item)` — items with
  `triggerPress(button)`; lets KeyboardPanel forward bar clicks through its
  fullscreen overlay (single-click panel switching)
- `requestPopout(key)` / `releasePopout(key)` — one popup open per bar
- `switchPanelFrom(item, direction)` — Tab cycles panels in layout order
- `targetBelongsToWindow(target, window)` — scene-graph containment check
- `moduleWidgets(name)` — ALL live instances of a module id across monitors
  (delegates to shell registry; powers `BarWidget.broadcast()`)

### Shell API (provided by shell.qml, consumed by Bar + modules)

- `summon(id, payloadJson)` -> bool — open a panel by id (OSD etc.); false = absent
- `updateEntryInline(moduleName, settings)` -> bool — persist per-module settings
- `firstPartyServiceFor(id)` -> var/null — shared service lookup (media, etc.)
- `claimPanelIpc(moduleName)` -> bool — exactly one instance per id owns its
  IpcHandler across monitors; others set `manageIpc: false` and relay via broadcast
- `instancesOf(moduleName)` — live module instances (register/unregister lifecycle)

Module contract (every bar module): properties `bar`, `moduleName`, `settings`;
panels additionally `open()/close()/toggle()/opened` and optional `manageIpc`.

### IPC surface (hyprland keybinds -> shell)

`quickshell ipc call shell <function>` on target `shell`:
`ping`, `reload`, `toggle <id>`, `openPanel <id>`, `closePanel <id>`,
`listPanels` (function names avoid `show`/`hide` — reserved CLI words).
Keybind map: Super+Ctrl+A/W/B/D/P -> toggle qs.audio/qs.network/qs.bluetooth/
qs.monitor/qs.power.

### Module ids and namespacing

Registry ids are bare (`"audio"`); moduleNames/ipcTargets are namespaced
(`qs.audio`). Vendored Omarchy code keeps internal names; adaptation renames
`omarchy.*` -> `qs.*` and script literals `omarchy-<x>` -> `qs-<x>`.

### Helper scripts (L7 bridge, `~/dotfiles/.local/share/bin/qs-*`)

Thin CLI wrappers over system tools (pactl/wpctl/nmcli/bluetoothctl/
powerprofilesctl/upower/hyprctl/jq). Contract: JSON or line output on stdout,
exit != 0 on failure, no OMARCHY_PATH deps, Fedora-compatible.
Scripts must exist before their panel is marked done.

### Theming flow

matugen template `~/.config/matugen/templates/quickshell.json` ->
`~/.config/quickshell/colors.json` (Material You roles: primary, on_background,
surface_bright, outline, error, ...). `Commons/Color.qml` FileView-watches it
and exposes: `foreground background accent urgent muted` + `bar{} popups{}
tooltip{}` namespaces. Never hand-edit colors.json.

### Config

`layout.json` (this dir, stowed): `{ "left": [...], "center": [...],
"right": [...] }` with entries `{"id": "audio", ...inline settings}`.
A center entry may set `"anchor": true` — that widget pins to the exact
screen center and other center entries flank it (the clock stays
dead-center next to the wsmode toggle). Adding a module = file +
Registry entry + layout entry.

## Directory map (subagent ownership)

| Path | Owner | Notes |
|---|---|---|
| shell.qml, Registry.qml, layout.json | foundation (done) | host + extension point |
| Bar/Bar.qml | foundation (done) | full Bar API |
| Commons/ (Color, Style, Util, Border) | foundation (done) | Color = matugen bridge |
| Ui/ | foundation (vendored) | namespaces renamed qs-* |
| Panels/audio + qs-audio-* | agent A1 | PipeWire/Mpris native; visualizer toggle row |
| Panels/network + qs-network-*/qs-dns | agent A2 | NM native + scripts |
| Panels/bluetooth + qs-bluetooth-* | agent A3 | BlueZ native |
| Panels/power + Panels/monitor + qs-* | agent A4 | UPower + brightness; tuned-adm profile section |
| Panels/clock, Bar/widgets/{Workspaces,Tray} | agent A5 | plain widgets |
| Bar/widgets/{CpuWidget,MemoryWidget,NetworkSpeedWidget,ClipboardWidget,AmphetamineWidget} | agent B1 | reuse user's waybar module scripts |
| matugen template, hyprland.conf binds, README, install | agent A6 | integration |

## Verification

- No qmlls guaranteed; syntax = `quickshell -p ~/dotfiles/.config/quickshell`
  in a nested Hyprland session once installed (`sudo dnf install quickshell`
  or COPR errornointernet/quickshell on F42).
- Contract compliance is grep-checkable: every `bar.X`/`shell.X` used by a
  module must appear in the Bar/Shell API lists above.
- IPC smoke: `quickshell ipc call shell ping` -> `ok`.

## Non-goals (v1)

No dynamic plugin scan (static Registry is enough for dotfiles), no bar
drag-reposition, no lockscreen/notifications/OSD takeover (swaync stays),
no vertical bar (property exists, untested).

Known deferred items (reported by module agents, consciously accepted):
- Summon ids `qs.osd`, `qs.speedtest`, `qs.wifiqr` are reserved but no
  overlay plugins exist; `shell.summon` returns false and call sites guard.

Environment quirks discovered at runtime (all fixed, documented for the
next debugger):
- **kanshi owns output config on this machine.** A bare `hyprctl keyword
  monitor` is reverted instantly by kanshi re-applying its profile.
  `qs-hyprland-monitor-scaling` therefore rewrites the scale inside every
  kanshi profile stanza that enables the focused output (managed via
  content rewrite, no marker block — kanshi has no include mechanism) and
  HUPs kanshi; the hyprctl keyword still runs for immediate effect.
- **WirePlumber here never promotes `default.configured.audio.*` to the
  live `default.audio.*` metadata key**, so wpctl/pactl default-switches
  silently no-op. `qs-audio-{output,input}-set-default` additionally write
  the live key via `pw-metadata`, which Quickshell's Pipewire bindings
  track reactively.
- **Style watches `~/.local/state/qs/display-text-size`** so the Display
  panel's text-size slider live-reflows the whole shell (bar height
  included) and the slider reflects the applied value.
- **Color polls colors.json every 1.5s** in addition to the FileView
  watch: matugen-style atomic writes can evade inotify watches. Identical
  content short-circuits before bindings re-evaluate.
- **Repeater delegates unregister on destruction** (Bar/Bar.qml): layout
  rewrites rebuild delegates, and without the destruction hook dead
  instances accumulate in the shell registry, holding IPC claims.
