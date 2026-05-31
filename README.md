
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

19. Reboot and enjoy

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

### Keybind cheat sheet

Press `Super+/` to open a searchable keybind reference. It parses `hyprland.conf` live so it's always up to date.

### btop config path

`btop` rewrites its full config (~272 lines) on every clean exit, using `rename()` — which severs any symlink at the destination. To keep the tracked config as the single source of truth, we run btop with `--config ~/dotfiles/.config/btop/btop.conf` directly, so rewrites land in the tracked file.

Wired up in two places:
- Shell alias in `init.sh` for terminal launches
- User `.desktop` override at `.local/share/applications/btop.desktop` for GUI launchers (takes precedence over `/usr/share/applications/btop.desktop` per XDG)

`.config/btop` is excluded from stow for this reason — nothing to symlink. The matugen-generated theme still lives at `~/.config/btop/themes/matugen.theme` (default path, regenerated per wallpaper change).

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
