#!/bin/bash
# Restart the cava visualizer (used by power profile keybinds)
pkill -f hypr-cava-visualizer.py 2>/dev/null
sleep 1
# Ensure old process is gone
pkill -9 -f hypr-cava-visualizer.py 2>/dev/null
sleep 0.5
exec env LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so.0 /usr/bin/python3 "$HOME/dotfiles/scripts/runtime/hypr-cava-visualizer.py"
