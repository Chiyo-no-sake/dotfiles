
# Dotfiles setup

Required install OS: Fedora 42 Workstation

Setup:
1. Install OS (+ hardware specific driver e.g. akmod-nvidia)
2. Add coprs:

```bash
sudo dnf copr enable -y emixampp/synology-drive 
sudo dnf copr enable -y sdegler/hyprland
sudo dnf copr enable -y erikreider/SwayNotificationCenter
sudo dnf copr enable -y atim/lazygit
```

3. Add yum VSCODE repo

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
```


4. Install:

```bash
sudo dnf install -y cmake meson cpio pkg-config git g++ gcc mesa-libGL-devel aquamarine-devel hyprlang-devel hyprcursor-devel hyprland-devel chafa stow hyprland hypridle hyprcursor hyprlock hyprpaper waybar nvim luarocks lua5.1 blueman blueman-applet pavucontrol zsh rofi-wayland zoxide synology-drive-noextra code readline-devel sqlite-devel tk-devel libffi-devel openssl-devel zlib-devel pamixer SwayNotificationCenter libappindicator nm-applet fd go ruby gem composer php julia lazygit hyprshot hyprpolkitagent libscfg scdoc libvarlink kanshi gnome-tweaks gnome-shell-extension-pop-shell xprop uv \
  cava playerctl brightnessctl socat tuned jq acpi ripgrep fzf wget curl libnotify gnome-keyring matugen swww fuzzel bemoji direnv NetworkManager-connection-editor pipewire-utils \
  gtk4-layer-shell python3-gobject python3-cairo \
  adw-gtk3-theme kvantum qt5ct qt6ct \
  btop kitty starship
```

5. Install hypr-cava-visualizer and hypr-scroll-indicator:

```bash
cd /tmp
git clone https://github.com/Chiyo-no-sake/hypr-cava-visualizer.git
cd hypr-cava-visualizer && sudo make install && cd /tmp

git clone https://github.com/Chiyo-no-sake/hypr-scroll-indicator.git
cd hypr-scroll-indicator && sudo make install
```

6. Install yazi (terminal file manager):

```bash
cd /tmp
curl -sLO "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip"
unzip yazi-x86_64-unknown-linux-gnu.zip
install -m 755 yazi-x86_64-unknown-linux-gnu/yazi ~/.local/bin/yazi
install -m 755 yazi-x86_64-unknown-linux-gnu/ya ~/.local/bin/ya
```

7. Install starship:
   
```bash
curl -sS https://starship.rs/install.sh | sh
```

8. Build libxkbcommon 1.11.0 (needed for hyprpm — Fedora 42 ships 1.8.1)

```bash
sudo dnf install meson ninja-build bison flex wayland-devel wayland-protocols-devel libxml2-devel xkeyboard-config-devel
cd /tmp
git clone --depth 50 --branch xkbcommon-1.11.0 https://github.com/xkbcommon/libxkbcommon.git libxkbcommon-build
cd libxkbcommon-build
meson setup build -Dprefix=/usr/local -Denable-docs=false
ninja -C build
sudo ninja -C build install
```

9. Install hyprpm build deps and all hypr -devel packages

```bash
sudo dnf install \
  libuuid-devel pango-devel libXcursor-devel libinput-devel \
  mesa-libgbm-devel re2-devel muParser-devel xcb-util-wm-devel \
  xcb-util-errors-devel tomlplusplus-devel libxkbcommon-devel \
  cmake gcc-c++ \
  hyprcursor-devel hyprgraphics-devel hyprlang-devel hyprtoolkit-devel \
  hyprutils-devel hyprwayland-scanner-devel hyprwire-devel hyprland-protocols-devel
```

10. Install hypr plugins

> **Important:** hyprpm requires the custom xkbcommon. Always use the `PKG_CONFIG_PATH` prefix:

```bash
PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprexpo
```


11. Run setup:

```bash
cd $HOME/dotfiles/scripts && ./setup.sh
```

12. Install required rocks

```sh
sudo luarocks --lua-version 5.1 install jsregexp
```

13. Start a new shell (open new terminal)

14. Stow files
```sh
cd $HOME/dotfiles && stow --adopt .
```

15. Install Flatpak apps

```bash
flatpak install com.spotify.Client dev.vencord.Vesktop org.mozilla.Thunderbird
```

16. Set GTK3 theme to adw-gtk3-dark

```bash
# In ~/.config/gtk-3.0/settings.ini, change:
# gtk-theme-name=adw-gtk3-dark
sed -i 's/gtk-theme-name=.*/gtk-theme-name=adw-gtk3-dark/' ~/.config/gtk-3.0/settings.ini
```

17. Set up KDE/Qt theming

KDE apps (Dolphin, etc.) use `kdeglobals` and the `Nothing.colors` color scheme. Matugen auto-generates both on wallpaper change. Manual one-time setup:

```bash
# Set KDE color scheme
kwriteconfig6 --file ~/.config/kdeglobals --group "General" --key "ColorScheme" "Nothing"
kwriteconfig6 --file ~/.config/kdedefaults/kdeglobals --group "General" --key "ColorScheme" "Nothing"

# Set up Kvantum base theme (SVG for widget shapes)
mkdir -p ~/.config/Kvantum/matugen
cp /usr/share/Kvantum/KvArcDark/KvArcDark.svg ~/.config/Kvantum/matugen/matugen.svg

# Set Kvantum active theme
cat > ~/.config/Kvantum/kvantum.kvconfig << 'EOF'
[General]
theme=matugen
EOF

# Set up qt6ct
mkdir -p ~/.config/qt6ct/colors
cat > ~/.config/qt6ct/qt6ct.conf << 'EOF'
[Appearance]
style=kvantum-dark
color_scheme_path=/home/$USER/.config/qt6ct/colors/matugen.conf
custom_palette=true
EOF

# Run matugen once to generate all color configs
matugen image <your-wallpaper-path>
```

18. Load Chrome theme extensions

Open Chrome, go to `chrome://extensions/`, enable **Developer mode**, then load two unpacked extensions:
- `~/.config/chrome-theme/` — the generated Material You theme
- `~/.config/chrome-theme-reloader/` — auto-reloads the theme on wallpaper change

The theme is generated automatically by matugen on each wallpaper change. On fresh boot, Chrome picks up the latest colors at launch. The reloader handles live updates while Chrome is running.

19. Apply ethernet stability fixes (Intel I219-LM + ASIX AX88179)

Both NICs on this laptop drop their link every few days from two unrelated bugs:
- Intel I219-LM (`e1000e`): Energy Efficient Ethernet LPI mis-negotiates with the PHY. Journal shows `EEE TX LPI TIMER: ... NIC Link is Down`.
- ASIX AX88179/AX88179A USB dongle: USB autosuspend silently kills the link after idle time.

Install a NetworkManager dispatcher (disables EEE on every wired link-up) and a udev rule (keeps the ASIX dongle out of autosuspend on every plug-in):

```bash
sudo install -o root -g root -m 0755 /dev/stdin /etc/NetworkManager/dispatcher.d/50-disable-ethernet-eee <<'EOF'
#!/usr/bin/env bash
set -eu
IFACE="${1:-}"
ACTION="${2:-}"
case "$IFACE" in enp*|eth*) ;; *) exit 0 ;; esac
case "$ACTION" in
    up|pre-up|connectivity-change)
        /usr/sbin/ethtool --set-eee "$IFACE" eee off >/dev/null 2>&1 || true
        ;;
esac
EOF

sudo install -o root -g root -m 0644 /dev/stdin /etc/udev/rules.d/50-asix-ax88179-no-autosuspend.rules <<'EOF'
# ASIX AX88179/AX88179A USB Gigabit Ethernet — disable USB autosuspend
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0b95", ATTR{idProduct}=="1790", TEST=="power/control", ATTR{power/control}="on"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=0b95
```

20. Reboot and enjoy

## Notes

### Dynamic theming

All colors are derived from the current wallpaper via matugen. Changing wallpaper (`Super+Shift+W`) automatically updates:
- Hyprland border colors
- Waybar colors
- Kitty terminal colors
- Rofi launcher colors
- Fuzzel colors
- SwayNC notification colors
- GTK3/GTK4 app colors
- KDE/Qt app colors (live reload via D-Bus signal)
- Chrome browser UI (frame, toolbar, tabs, omnibox, NTP)
- Yazi file manager colors
- btop system monitor colors
- Cava audio visualizer colors
- Breeze folder icon accent colors
- AURA RGB LEDs — fans, GPU, cooler (this PC only, via OpenRGB)

KDE apps with folder previews (thumbnails) need F5 to refresh after wallpaper change — this is a Dolphin caching limitation.

#### Light/dark live switcher

`scripts/runtime/theme-toggle.sh` flips between matugen's light and dark variants of the **current wallpaper** without changing the image. It reruns matugen with `--mode light|dark` and replays the same reload pipeline as the wallpaper cycler, so kitty, hyprland, waybar, nvim (live, via `--remote-send` on `/run/user/$UID/nvim.*`), swaync and the scroll indicator all update in place.

Triggers:
- `Super+Shift+T` — Hyprland keybinding
- Waybar sun/moon module in the center cluster — click to toggle

The choice persists in `~/.cache/theme-mode`. `wallpaper-cycle.sh` reads that file so the daemon keeps you in light mode across wallpaper rotations until you toggle back.

### Quickshell bar (opt-in waybar replacement)

A custom Hyprland shell built on [Quickshell](https://quickshell.outfoxxed.me) with Omarchy-derived panels: audio (volume + output picker + per-app mixer), network, bluetooth, power, monitor — plus waybar-parity widgets (workspaces, clock, tray). Architecture, layer contracts and the extension points are documented in `.config/quickshell/ARCHITECTURE.md`.

Install (Fedora 42):

```bash
sudo dnf install quickshell
# fallback if the package is not in the enabled repos:
sudo dnf copr enable -y errornointernet/quickshell && sudo dnf install quickshell
```

Theming is automatic: `[templates.quickshell]` in `.config/matugen/config.toml` renders the palette from `.config/matugen/templates/quickshell.json` to `~/.config/quickshell/colors.json` (generated at runtime, gitignored) on every wallpaper change. The bar's `Commons/Color.qml` watches that file and re-themes every surface live — never hand-edit it.

Trying it alongside waybar (safe: both bars render as separate layers, waybar stays untouched):

```bash
quickshell -p ~/.config/quickshell                             # start the bar manually
qs-bar-reload                                                  # restart it after big config changes
quickshell ipc -p ~/.config/quickshell call shell ping         # IPC smoke test -> "ok"
```

Panel keybinds (in `hyprland.conf`; Super+Ctrl was unused, so no collisions with the `Super+A`/`Super+B` pypr toggles):

- `Super+Ctrl+A` — audio panel
- `Super+Ctrl+W` — network panel
- `Super+Ctrl+B` — bluetooth panel
- `Super+Ctrl+D` — monitor panel (brightness/scaling)
- `Super+Ctrl+P` — power panel (battery/profiles)

To make it the primary bar, uncomment `exec-once = quickshell -p ~/.config/quickshell` in the AUTOSTART section of `hyprland.conf` and comment out the waybar `exec` line above it. Rollback is the reverse — one line each way.

Adding a module is one file + one registry line + one layout entry:

1. Create `Panels/<name>/` (popup-capable) or `Bar/widgets/<name>.qml` (plain widget) implementing the module contract (`bar`, `moduleName`, `settings`; panels add `open()/close()/toggle()`).
2. Register it in `.config/quickshell/Registry.qml` (id -> component URL).
3. Add `{ "id": "<name>" }` to the desired section of `.config/quickshell/layout.json`.

### Audio visualizer

A cava-based audio visualizer runs on the Wayland background layer behind all windows. It auto-detects monitor refresh rate and scales framerate based on power profile. Restart it after power profile change via `Super+F7/F8/F9`.

### AURA RGB hardware sync (desktop only)

This machine (`fedora-sin`) has AURA-compatible RGB hardware (fans, GPU, cooler). Matugen drives it so the physical lighting follows the wallpaper accent. The `aura-sync.sh` hook self-gates by hostname, so this is a no-op on any other machine (e.g. the laptop) and on machines without OpenRGB.

One-time setup:

```bash
# 1. Install OpenRGB (controls AURA / Aura Sync devices on Linux)
sudo dnf install -y openrgb

# 2. Motherboard/RAM RGB over SMBus needs the ACPI resource lock relaxed.
#    Add the kernel param, then reboot. (i2c-dev is already autoloaded.)
sudo grubby --update-kernel=ALL --args="acpi_enforce_resources=lax"

# 3. After reboot, confirm what OpenRGB can see and control:
openrgb --list-devices
```

OpenRGB installs udev rules for non-root USB/i2c access automatically; reboot (or log out/in) so they apply. If a device exposes a `direct` but not a `static` mode, adjust the `apply` order in `scripts/runtime/aura-sync.sh`.

**How it works:** the `[templates.aura]` matugen template writes the palette to `~/.config/aura-colors/colors.json` (generated at runtime — not committed), then the `aura-sync.sh` post_hook pushes the `primary` color to every detected device on each wallpaper change (`Super+Shift+W`). Change the `ROLE` variable in the script to drive the LEDs from `secondary`/`tertiary` instead.

### Bluetooth headset: prevent auto-downgrade to mono call quality

Classic Bluetooth headsets (e.g. Sony WH-1000XM3) can't run A2DP (stereo output) and HFP (mic) at once. By default WirePlumber auto-switches the whole card to mono HSP/HFP the instant any app opens the headset's mic — including apps like Discord that transiently probe the mic even when it isn't the selected input device. This tanks output quality for calls even if you only ever use the laptop mic.

`.config/wireplumber/wireplumber.conf.d/51-bluez-no-autoswitch.conf` sets `bluetooth.autoswitch-to-headset-profile = false`, so the card stays on A2DP regardless of what opens the mic. Applied automatically by `stow .`; no separate install step. If a device ever gets stuck in `headset-head-unit` (e.g. mid-call after a manual profile change), force it back with:

```bash
pactl set-card-profile bluez_card.<MAC_with_underscores> a2dp-sink
```

### Amphetamine (keep-awake)

`scripts/runtime/amphetamine.sh` temporarily disables hypridle so the screen stays on (no dim, no lock, no dpms-off, no suspend). hypridle has no IPC, so "on" kills the daemon and "off" respawns it via `hyprctl dispatch exec` (parented to Hyprland, so it survives waybar reloads). State persists in `~/.cache/amphetamine` (`inf` or an epoch expiry); a stale file from a previous session is auto-cleared on the first status poll.

Waybar eye module in the right cluster:
- Click — toggle staying awake indefinitely
- Right-click — stay awake for 60 min (repeat clicks stack +60 min; shows a countdown)
- Active state is highlighted in the error color so you don't forget it's on

CLI: `amphetamine.sh {on [min]|off|toggle|bump [min]|status}`.

### Clipboard history

`cliphist` records every clipboard change into `~/.cache/cliphist/db` via `wl-paste --watch cliphist store` (started in `hyprland.conf`, max 750 entries).

Installed as a static release binary at `.local/share/bin/cliphist` (on PATH) — the sdegler/hyprland copr no longer builds for Fedora 42. To update:

```bash
cd ~/dotfiles/.local/share/bin
curl -sL -o cliphist "https://github.com/sentriz/cliphist/releases/download/v0.7.0/v0.7.0-linux-amd64"
chmod +x cliphist
```

- `Super+V` — rofi picker (`scripts/runtime/clipboard-history.sh`), themed by `.config/rofi/clipboard.rasi` with matugen colors
- Waybar module (right cluster, next to the tray): click — pick an entry, middle-click — delete entries (multi-select), right-click — wipe history; tooltip shows the last 8 entries

Caveat: history is stored in plaintext, so copied passwords (e.g. from Bitwarden) end up in it — right-click the waybar module to wipe.

### Keybind cheat sheet

Press `Super+/` to open a searchable keybind reference. It parses `hyprland.conf` live so it's always up to date.

### btop config path

`btop` rewrites its full config (~272 lines) on every clean exit, using `rename()` — which severs any symlink at the destination. To keep the tracked config as the single source of truth, we run btop with `--config ~/dotfiles/.config/btop/btop.conf` directly, so rewrites land in the tracked file.

Wired up in two places:
- Shell alias in `init.sh` for terminal launches
- User `.desktop` override at `.local/share/applications/btop.desktop` for GUI launchers (takes precedence over `/usr/share/applications/btop.desktop` per XDG)

`.config/btop` is excluded from stow for this reason — nothing to symlink. The matugen-generated theme still lives at `~/.config/btop/themes/matugen.theme` (default path, regenerated per wallpaper change).

### Dev-tool resource cages (keep tsc / quality / pytest from saturating the machine)

Heavy dev commands — especially agents invoking them as `bunx tsc`,
`bun run quality` (webapp) or `uv run pytest` (backend) — can eat the whole
box. Shell wrappers can't intercept these (agents spawn non-interactive
shells; package managers resolve `node_modules/.bin` paths directly), so
instead user systemd units cage the processes at the cgroup level:

- `tsc-cage.service` — `CPUQuota=400%` + `MemoryMax=4G`. Cages tsc and the
  whole `quality` pipeline (dedupe, prettier, depcruise, eslint).
- `pytest-cage.service` — `CPUQuota=800%` + `MemoryMax=8G`. Cages pytest via
  `uv run pytest`, `.venv/bin/pytest` or `python -m pytest`, including xdist
  workers (backend runs `-n 6`).
- `dev-cage-watcher.service` — runs `scripts/runtime/dev-cage-watcher.sh`,
  which every second migrates any process matching a rule (plus its **entire
  subtree**, so multi-process chains like `bun run quality → node …/bin/tsc`
  are fully covered) into the matching cage. Children born after a migration
  inherit the cage automatically; over-limit memory is OOM-killed inside the
  cage only. Patterns match real invocations (script paths, `run <script>`
  argv), so commands that merely mention a tool are never caged.

One-time setup (after `stow .`):

```bash
systemctl --user daemon-reload
systemctl --user enable --now tsc-cage.service pytest-cage.service dev-cage-watcher.service
```

Verify: run `bun run quality` / `uv run pytest` and check
`systemctl --user status tsc-cage.service pytest-cage.service` — the PIDs
appear in the CGroup line (`nr_throttled` climbs in the cage's `cpu.stat`
under load). To change a ceiling, edit the cage unit, then
`systemctl --user daemon-reload && systemctl --user restart <cage>`.

Caveat: concurrent runs share their cage's budget (two tscs split 4 cores /
4 GiB), and a kill-everything-in-the-cage cleanup will also hit unrelated
runs that legitimately landed there — kill by PID, not by cage.

### Bitwarden (desktop + biometric unlock)

Installed from the official RPM (native package — supports both browser integration
and "Unlock with system authentication", unlike the Flatpak/AppImage builds). It is
**not** in a dnf repo, so it does not auto-update and the package is unsigned:

```bash
# Download the latest desktop RPM (redirects to GitHub release assets — slow on a
# single stream, so pull it in parallel with aria2):
sudo dnf install -y aria2
aria2c -x16 -s16 -k1M "https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=rpm"
sudo dnf install -y --nogpgcheck ./Bitwarden-*.rpm
```

To update later, re-download and `sudo dnf install` the newer RPM.

Autostarted via `$bitwarden = bitwarden` + `exec-once = $bitwarden &` in `hyprland.conf`.

**Biometric unlock (Howdy face auth):** unlock delegates to polkit → PAM, so it reuses
the existing Howdy setup — no Bitwarden-specific config needed. Requirements (all already
in place): `pam_howdy.so` in `/etc/pam.d/polkit-1`, a running polkit agent
(`hyprpolkitagent`, autostarted), and the `gnome-keyring` secret service (autostarted).
Then enable in-app: **Settings → Security → Unlock with system authentication**. You still
log in once per app start with the master password/PIN; biometrics unlock thereafter.

## Claude Code: personal plugin marketplace

A personal Claude Code marketplace lives at `.claude/marketplace/` in this repo
(`luca-dotfiles`). It holds the `sq` plugin, whose `auto-do` skill drives a
YouTrack issue from ticket to PR across the three shootify repos
(invoke with `/sq:auto-do SHO-1234`).

Layout:

```
.claude/marketplace/
  .claude-plugin/marketplace.json
  plugins/sq/
    .claude-plugin/plugin.json
    skills/auto-do/SKILL.md
```

The marketplace is registered **by local path** (Claude reads it straight from
this repo — no Stow symlink required). To set it up on a fresh machine:

```bash
claude plugin marketplace add ~/dotfiles/.claude/marketplace
claude plugin install sq@luca-dotfiles
```

To pick up edits to the skill after pulling changes:

```bash
claude plugin marketplace update luca-dotfiles
```
# Local speech-to-text development

The Intel NPU integration is developed in `~/repos/hyprwhspr`; do not use a
temporary checkout because model exports and compiled OpenVINO caches are large
and persistent during hardware validation.

Hyprland's animated mic OSD uses Fedora's native GTK4 bindings, while the
OpenVINO service runs in a Python 3.11 virtual environment. Create a small
Python 3.13 OSD environment that inherits the system GTK packages and supplies
NumPy:

```bash
python3 -m venv --system-site-packages ~/.local/share/hyprwhspr/mic-osd-venv
~/.local/share/hyprwhspr/mic-osd-venv/bin/python -m pip install numpy==2.2.6
```

The service discovers this interpreter automatically. Verify overlay mode with:

```bash
hyprwhspr mic-osd status
journalctl --user -u hyprwhspr.service | grep 'Mic-OSD daemon started'
```

Hyprland starts `hyprwhspr.service` explicitly after importing the Wayland
environment. This is required because Hyprland does not activate systemd's
`graphical-session.target`, even when the service is enabled under that target.

Speech-to-text uses push-to-talk: hold `Super+M` to record, then release `M` to
stop, transcribe, and insert the text at the focused cursor. The corresponding
hyprwhspr setting is `"recording_mode": "push_to_talk"`. The binding uses
`scripts/runtime/hyprwhspr-push-to-talk.sh`, which retries a release that lands
while the daemon is still finishing recording startup.

The OpenVINO NPU backend uses the multilingual Whisper `small` model with
automatic language detection (`"language": null`), so the same shortcut works
for both English and Italian. Models ending in `.en` are English-only and must
not be used for bilingual dictation. Keep `"sampling_strategy": "greedy"`:
OpenVINO's static NPU Whisper pipeline does not support beam search.

On Fedora, Intel NPU acceleration requires all of the following:

- `intel_vpu` kernel driver and `/dev/accel/accel0`
- Intel NPU Level Zero UMD (`libze_intel_npu.so`)
- Intel NPU compiler (`libopenvino_intel_npu_compiler.so`)
- A mutually supported OpenVINO/UMD/compiler release combination

Verify the userspace stack from the hyprwhspr virtual environment:

```bash
python -c 'import openvino as ov; c=ov.Core(); print(c.available_devices); print(c.get_property("NPU", "NPU_COMPILER_VERSION"))'
```

`NPU_COMPILER_VERSION=0` means the device is visible but the compiler interface
is missing or incompatible. Update the Intel NPU userspace driver before relying
on NPU acceleration. The hyprwhspr backend falls back to OpenVINO CPU by default.
# Intel NPU userspace driver

Meteor Lake NPU inference through OpenVINO requires the Intel Level Zero NPU
UMD and matching NPU compiler in addition to Fedora's `intel_vpu` kernel driver.
Install the tested Intel `1.35.0` userspace release with:

```bash
bash ~/dotfiles/scripts/runtime/install-intel-npu-userspace.sh install
```

The script downloads the release into `~/.cache/intel-npu-driver/`, verifies its
SHA-256, preserves existing compatibility links, installs only the userspace UMD
and compiler into `/usr/lib64`, runs `ldconfig`, and verifies that OpenVINO
reports a non-zero `NPU_COMPILER_VERSION`. It does not replace Fedora's kernel
module or firmware. This matches Intel's package layout and lets `ldconfig`
select the newest versioned `libze_intel_npu.so` implementation.

Verification and rollback:

```bash
bash ~/dotfiles/scripts/runtime/install-intel-npu-userspace.sh verify
bash ~/dotfiles/scripts/runtime/install-intel-npu-userspace.sh rollback
```
