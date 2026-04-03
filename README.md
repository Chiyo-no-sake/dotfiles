
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
sudo dnf install -y cmake meson cpio pkg-config git g++ gcc mesa-libGL-devel aquamarine-devel hyprlang-devel hyprcursor-devel hyprland-devel chafa stow hyprland hypridle hyprcursor hyprlock hyprpaper waybar nvim ranger luarocks lua5.1 blueman blueman-applet pavucontrol zsh rofi-wayland zoxide synology-drive-noextra code readline-devel sqlite-devel tk-devel libffi-devel openssl-devel zlib-devel pamixer SwayNotificationCenter libappindicator nm-applet fd go ruby gem composer php julia lazygit hyprshot hyprpolkitagent libscfg scdoc libvarlink kanshi gnome-tweaks gnome-shell-extension-pop-shell xprop uv
```

5. Install starship:
   
```bash
curl -sS https://starship.rs/install.sh | sh
```

6. Build libxkbcommon 1.11.0 (needed for hyprpm — Fedora 42 ships 1.8.1)

```bash
sudo dnf install meson ninja-build bison flex wayland-devel wayland-protocols-devel libxml2-devel xkeyboard-config-devel
cd /tmp
git clone --depth 50 --branch xkbcommon-1.11.0 https://github.com/xkbcommon/libxkbcommon.git libxkbcommon-build
cd libxkbcommon-build
meson setup build -Dprefix=/usr/local -Denable-docs=false
ninja -C build
sudo ninja -C build install
```

7. Install hyprpm build deps and all hypr -devel packages

```bash
sudo dnf install \
  libuuid-devel pango-devel libXcursor-devel libinput-devel \
  mesa-libgbm-devel re2-devel muParser-devel xcb-util-wm-devel \
  xcb-util-errors-devel tomlplusplus-devel libxkbcommon-devel \
  cmake gcc-c++ \
  hyprcursor-devel hyprgraphics-devel hyprlang-devel hyprtoolkit-devel \
  hyprutils-devel hyprwayland-scanner-devel hyprwire-devel hyprland-protocols-devel
```

8. Install hypr plugins

> **Important:** hyprpm requires the custom xkbcommon. Always use the `PKG_CONFIG_PATH` prefix:

```bash
PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprexpo
```


9. Run setup:

```bash
cd $HOME/dotfiles/scripts && ./setup.sh
```

10. Install required rocks

```sh
sudo luarocks --lua-version 5.1 install jsregexp
```

11. Start a new shell (open new terminal)

12. Stow files
```sh
cd $HOME/dotfiles && stow --adopt .
```

13. Reboot and enjoy
