#!/usr/bin/env bash
# Waybar wrapper around theme-toggle.sh.
#
# We invoke theme-toggle.sh INLINE (synchronously) on purpose: matugen needs
# the session's inherited TTY, so the pipeline must not be detached. The
# engine reloads waybar (`pkill -SIGUSR2 waybar`) as its LAST step, so by the
# time that bar reload kills this on-click child, every app (kitty, nvim,
# swaync, ...) has already been reloaded.

MODE_FILE="$HOME/.cache/theme-mode"
TOGGLE="$HOME/dotfiles/scripts/runtime/theme-toggle.sh"

if [[ "$1" == "toggle" ]]; then
    "$TOGGLE" toggle >/dev/null 2>&1
fi

mode="dark"
[[ -f "$MODE_FILE" ]] && mode="$(cat "$MODE_FILE")"

if [[ "$mode" == "light" ]]; then
    echo '{"text": "󰖨", "class": "light", "tooltip": "Theme: light (click for dark)"}'
else
    echo '{"text": "󰽢", "class": "dark", "tooltip": "Theme: dark (click for light)"}'
fi
