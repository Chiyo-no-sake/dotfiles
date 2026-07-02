#!/bin/bash
# Dynamic wallpaper theming pipeline
# Usage:
#   wallpaper-cycle.sh          - pick random wallpaper and apply theme
#   wallpaper-cycle.sh daemon   - loop with timer
#   wallpaper-cycle.sh <path>   - apply specific wallpaper

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/dotfiles/backgrounds}"
INTERVAL="${WALLPAPER_INTERVAL:-1800}"  # 30 min default
CURRENT_FILE="$HOME/.cache/current-wallpaper"
MODE_FILE="$HOME/.cache/theme-mode"

apply_wallpaper() {
    local wallpaper="$1"

    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: wallpaper not found: $wallpaper" >&2
        return 1
    fi

    # Honor persisted light/dark choice set by theme-toggle.sh
    local mode="dark"
    [[ -f "$MODE_FILE" ]] && mode="$(cat "$MODE_FILE")"

    # Set wallpaper with smooth transition
    swww img "$wallpaper" \
        --transition-type fade \
        --transition-duration 2 \
        --transition-fps 60

    # Generate colors and expand all templates (scheme_type from config.toml)
    matugen --mode "$mode" image "$wallpaper"

    # Reload Hyprland to pick up new colors.conf
    hyprctl reload

    # Hot-reload waybar CSS (SIGUSR2) instead of restarting — keeps any
    # in-flight click handler alive and preserves the inherited TTY for
    # matugen on next invocation.
    pkill -SIGUSR2 waybar

    # Restart scroll indicator to pick up new colors
    pkill -f hypr-scroll-indicator
    hypr-scroll-indicator --colors-file ~/.config/hypr/colors.conf --hyprland-conf ~/.config/hypr/hyprland.conf &

    # Reload kitty colors (all running instances)
    for sock in /tmp/kitty-*; do
        kitty @ --to unix:"$sock" load-config 2>/dev/null
    done

    # Reload nvim colorscheme in every running instance
    local remote_cmd=":lua vim.o.background='${mode}'; package.loaded['matugen_colors']=nil; vim.cmd('colorscheme matugen')<CR>"
    shopt -s nullglob
    for sock in /run/user/"$(id -u)"/nvim.*; do
        [[ -S "$sock" ]] || continue
        nvim --server "$sock" --remote-send "$remote_cmd" 2>/dev/null || true
    done
    shopt -u nullglob

    # Reload swaync
    swaync-client -rs 2>/dev/null

    # Save current wallpaper path
    echo "$wallpaper" > "$CURRENT_FILE"
}

pick_random() {
    find "$WALLPAPER_DIR" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \) | shuf -n1
}

case "${1:-}" in
    daemon)
        # Ensure swww daemon is running
        swww-daemon &>/dev/null &
        sleep 0.5
        while true; do
            apply_wallpaper "$(pick_random)"
            sleep "$INTERVAL"
        done
        ;;
    "")
        apply_wallpaper "$(pick_random)"
        ;;
    *)
        apply_wallpaper "$1"
        ;;
esac
