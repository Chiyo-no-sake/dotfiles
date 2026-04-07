#!/bin/bash
# Toggle between a target workspace and the previous one.
# Usage: toggle-workspace.sh <workspace_id>

TARGET="${1:?Usage: toggle-workspace.sh <workspace_id>}"
CURRENT=$(hyprctl activeworkspace -j | jq '.id')

if [ "$CURRENT" = "$TARGET" ]; then
    hyprctl dispatch workspace previous
else
    hyprctl dispatch workspace "$TARGET"
fi
