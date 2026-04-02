#!/usr/bin/env bash
# Toggle or query Hyprland layout per-workspace (dwindle ↔ scrolling)

STATE_DIR="/tmp/hypr-layout-state"
mkdir -p "$STATE_DIR"

WS_ID=$(hyprctl activeworkspace -j | jq -r '.id')
DEFAULT_LAYOUT=$(hyprctl getoption general:layout -j | jq -r '.str')
STATE_FILE="$STATE_DIR/ws-$WS_ID"

# Current layout for this workspace
if [[ -f "$STATE_FILE" ]]; then
    current=$(cat "$STATE_FILE")
else
    current="$DEFAULT_LAYOUT"
fi

if [[ "$1" == "restore" ]]; then
    for f in "$STATE_DIR"/ws-*; do
        [[ -f "$f" ]] || continue
        ws="${f##*ws-}"
        layout=$(cat "$f")
        hyprctl keyword workspace "$ws, layout:$layout" >/dev/null 2>&1
    done
    exit 0
fi

if [[ "$1" == "toggle" ]]; then
    if [[ "$current" == "dwindle" ]]; then
        new="scrolling"
    else
        new="dwindle"
    fi
    hyprctl keyword workspace "$WS_ID, layout:$new"
    echo "$new" > "$STATE_FILE"
    current="$new"
fi

if [[ "$current" == "dwindle" ]]; then
    echo '{"text": "󰕰", "class": "dwindle", "tooltip": "Dwindle (ws '"$WS_ID"')"}'
else
    echo '{"text": "󱎞", "class": "scrolling", "tooltip": "Scrolling (ws '"$WS_ID"')"}'
fi
