#!/usr/bin/env bash
# Clipboard history picker (cliphist + rofi), themed via clipboard.rasi.
#
# Usage:
#   clipboard-history.sh        pick an entry -> copy it to the clipboard
#   clipboard-history.sh del    pick entries (multi-select) -> remove from history
#   clipboard-history.sh wipe   clear the whole history
#
# Requires: cliphist (.local/share/bin), wl-clipboard, rofi-wayland
#
# NOTE: absolute paths — spawned from waybar/Hyprland, whose session PATH does
# not include ~/.local/share/bin. Selection passes through a temp file (never a
# shell variable) so binary entries with NUL bytes survive, and an empty
# selection (Escape) must NOT reach wl-copy, which would wipe the clipboard.

set -euo pipefail

CLIPHIST="$HOME/dotfiles/.local/share/bin/cliphist"
theme="$HOME/.config/rofi/clipboard.rasi"
sel="$(mktemp)"
trap 'rm -f "$sel"' EXIT

case "${1:-pick}" in
    pick)
        "$CLIPHIST" list \
            | rofi -dmenu -i -p "󰅍 Clipboard" -theme "$theme" >"$sel"
        [[ -s "$sel" ]] && "$CLIPHIST" decode <"$sel" | wl-copy
        ;;
    del)
        "$CLIPHIST" list \
            | rofi -dmenu -i -multi-select -p "󰩺 Delete" -theme "$theme" >"$sel"
        [[ -s "$sel" ]] && "$CLIPHIST" delete <"$sel"
        ;;
    wipe)
        "$CLIPHIST" wipe
        notify-send "Clipboard" "History cleared"
        ;;
esac
