#!/bin/bash
# Restart the cava visualizer (used by power profile keybinds)
pkill -f hypr-cava-visualizer 2>/dev/null
sleep 0.5
pkill -9 -f hypr-cava-visualizer 2>/dev/null
# Kill orphaned cava processes spawned by previous visualizer instances
pkill -f "cava -p.*/hypr-cava-visualizer/" 2>/dev/null
sleep 0.3
exec hypr-cava-visualizer \
    --colors-file ~/.config/hypr/colors.conf \
    --height-pct 35 --opacity 0.33 \
    --fade --fade-in-speed 3.0 --fade-out-speed 1.5 \
    --silence-threshold 0.02 \
    --boost-saturation 0.25 --power-aware
