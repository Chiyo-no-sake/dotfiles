#!/bin/bash

# Rename the active Hyprland workspace via rofi dmenu popup.
# Usage:
#   rename-workspace.sh          # prompt for a new name
#   rename-workspace.sh --clear  # reset name back to just the workspace number

get_active_id() {
    hyprctl activeworkspace -j | jq -r '.id'
}

ws_id=$(get_active_id)

if [[ "$1" == "--clear" ]]; then
    hyprctl dispatch renameworkspace "$ws_id" ""
    exit 0
fi

name=$(rofi -dmenu \
    -p "Rename workspace" \
    -theme-str '@import "colors/catppuccin.rasi"' \
    -theme-str 'window { width: 320px; location: center; anchor: center; }' \
    -theme-str 'listview { enabled: false; }' \
    -theme-str 'inputbar { children: [prompt, textbox-prompt-colon, entry]; }' \
    -theme-str 'textbox-prompt-colon { str: ": "; }' \
    -theme-str '* { font: "JetBrains Mono Nerd Font 12"; }')

# Only rename if user typed something (not empty / not Escape)
if [[ -n "$name" ]]; then
    hyprctl dispatch renameworkspace "$ws_id" "$ws_id: $name"
fi
