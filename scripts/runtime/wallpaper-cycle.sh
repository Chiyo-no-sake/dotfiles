#!/bin/bash
# Dynamic wallpaper theming pipeline
# Usage:
#   wallpaper-cycle.sh          - pick random wallpaper and apply theme
#   wallpaper-cycle.sh daemon   - loop with timer
#   wallpaper-cycle.sh <path>   - apply specific wallpaper

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/dotfiles/backgrounds}"
INTERVAL="${WALLPAPER_INTERVAL:-1800}"  # 30 min default
CURRENT_FILE="$HOME/.cache/current-wallpaper"

apply_wallpaper() {
    local wallpaper="$1"

    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: wallpaper not found: $wallpaper" >&2
        return 1
    fi

    # Set wallpaper with smooth transition
    swww img "$wallpaper" \
        --transition-type fade \
        --transition-duration 2 \
        --transition-fps 60

    # Generate colors and expand all templates (scheme_type from config.toml)
    matugen image "$wallpaper"

    # Reload Hyprland to pick up new colors.conf
    hyprctl reload

    # Restart waybar to pick up new colors.css
    pkill waybar; waybar &

    # Restart scroll indicator to pick up new colors
    pkill -f hypr-scroll-indicator.py
    env LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so.0 /usr/bin/python3 \
        "$HOME/dotfiles/scripts/runtime/hypr-scroll-indicator.py" &

    # Reload kitty colors (all running instances)
    for sock in /tmp/kitty-*; do
        kitty @ --to unix:"$sock" load-config 2>/dev/null
    done

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
