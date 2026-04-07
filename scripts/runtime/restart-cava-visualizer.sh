#!/bin/bash
# Restart the cava visualizer (used by power profile keybinds)
pkill -f hypr-cava-visualizer 2>/dev/null
sleep 1
pkill -9 -f hypr-cava-visualizer 2>/dev/null
sleep 0.5
exec hypr-cava-visualizer \
    --colors-file ~/.config/hypr/colors.conf \
    --height-pct 35 --opacity 0.33 \
    --fade --fade-in-speed 3.0 --fade-out-speed 1.5 \
    --silence-threshold 0.02 \
    --boost-saturation 0.25 --power-aware
