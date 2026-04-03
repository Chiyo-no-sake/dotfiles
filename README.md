
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
  kitty starship
```

5. Install yazi (terminal file manager):

```bash
cd /tmp
curl -sLO "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip"
unzip yazi-x86_64-unknown-linux-gnu.zip
install -m 755 yazi-x86_64-unknown-linux-gnu/yazi ~/.local/bin/yazi
install -m 755 yazi-x86_64-unknown-linux-gnu/ya ~/.local/bin/ya
```

6. Install starship:
   
```bash
curl -sS https://starship.rs/install.sh | sh
```

7. Build libxkbcommon 1.11.0 (needed for hyprpm — Fedora 42 ships 1.8.1)

```bash
sudo dnf install meson ninja-build bison flex wayland-devel wayland-protocols-devel libxml2-devel xkeyboard-config-devel
cd /tmp
git clone --depth 50 --branch xkbcommon-1.11.0 https://github.com/xkbcommon/libxkbcommon.git libxkbcommon-build
cd libxkbcommon-build
meson setup build -Dprefix=/usr/local -Denable-docs=false
ninja -C build
sudo ninja -C build install
```

8. Install hyprpm build deps and all hypr -devel packages

```bash
sudo dnf install \
  libuuid-devel pango-devel libXcursor-devel libinput-devel \
  mesa-libgbm-devel re2-devel muParser-devel xcb-util-wm-devel \
  xcb-util-errors-devel tomlplusplus-devel libxkbcommon-devel \
  cmake gcc-c++ \
  hyprcursor-devel hyprgraphics-devel hyprlang-devel hyprtoolkit-devel \
  hyprutils-devel hyprwayland-scanner-devel hyprwire-devel hyprland-protocols-devel
```

9. Install hypr plugins

> **Important:** hyprpm requires the custom xkbcommon. Always use the `PKG_CONFIG_PATH` prefix:

```bash
PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprexpo
```


10. Run setup:

```bash
cd $HOME/dotfiles/scripts && ./setup.sh
```

11. Install required rocks

```sh
sudo luarocks --lua-version 5.1 install jsregexp
```

12. Start a new shell (open new terminal)

13. Stow files
```sh
cd $HOME/dotfiles && stow --adopt .
```

14. Install Flatpak apps

```bash
flatpak install com.spotify.Client dev.vencord.Vesktop org.mozilla.Thunderbird
```

15. Set GTK3 theme to adw-gtk3-dark

```bash
# In ~/.config/gtk-3.0/settings.ini, change:
# gtk-theme-name=adw-gtk3-dark
sed -i 's/gtk-theme-name=.*/gtk-theme-name=adw-gtk3-dark/' ~/.config/gtk-3.0/settings.ini
```

16. Set up KDE/Qt theming

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

17. Load Chrome theme extensions

Open Chrome, go to `chrome://extensions/`, enable **Developer mode**, then load two unpacked extensions:
- `~/.config/chrome-theme/` — the generated Material You theme
- `~/.config/chrome-theme-reloader/` — auto-reloads the theme on wallpaper change

The theme is generated automatically by matugen on each wallpaper change. On fresh boot, Chrome picks up the latest colors at launch. The reloader handles live updates while Chrome is running.

18. Reboot and enjoy

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
- Cava audio visualizer colors
- Breeze folder icon accent colors

KDE apps with folder previews (thumbnails) need F5 to refresh after wallpaper change — this is a Dolphin caching limitation.

### Audio visualizer

A cava-based audio visualizer runs on the Wayland background layer behind all windows. It auto-detects monitor refresh rate and scales framerate based on power profile. Restart it after power profile change via `Super+F7/F8/F9`.

### Keybind cheat sheet

Press `Super+/` to open a searchable keybind reference. It parses `hyprland.conf` live so it's always up to date.
