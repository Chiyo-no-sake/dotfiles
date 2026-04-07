#!/bin/bash
# Toggle the cava visualizer on/off, output JSON for waybar

if [ "$1" = "toggle" ]; then
    if pgrep -f hypr-cava-visualizer > /dev/null; then
        pkill -f hypr-cava-visualizer
    else
        "$HOME/dotfiles/scripts/runtime/restart-cava-visualizer.sh" &
        disown
    fi
fi

if pgrep -f hypr-cava-visualizer > /dev/null; then
    echo '{"text": "󰓃", "class": "on", "tooltip": "Visualizer: ON"}'
else
    echo '{"text": "󰓃", "class": "off", "tooltip": "Visualizer: OFF"}'
fi
