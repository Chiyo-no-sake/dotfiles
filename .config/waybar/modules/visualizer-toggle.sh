#!/bin/bash
# Toggle the cava visualizer on/off, output JSON for waybar

if [ "$1" = "toggle" ]; then
    if pgrep -f hypr-cava-visualizer.py > /dev/null; then
        pkill -f hypr-cava-visualizer.py
    else
        env LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so.0 \
            /usr/bin/python3 "$HOME/dotfiles/scripts/runtime/hypr-cava-visualizer.py" &
        disown
    fi
fi

if pgrep -f hypr-cava-visualizer.py > /dev/null; then
    echo '{"text": "󰓃", "class": "on", "tooltip": "Visualizer: ON"}'
else
    echo '{"text": "󰓃", "class": "off", "tooltip": "Visualizer: OFF"}'
fi
