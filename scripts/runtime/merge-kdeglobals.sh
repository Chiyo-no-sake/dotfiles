#!/bin/bash
# Merge matugen-generated KDE colors into kdeglobals without losing user settings
# Usage: merge-kdeglobals.sh <generated-colors-file>

COLORS="$1"
TARGET="$HOME/.config/kdeglobals"

if [ ! -f "$COLORS" ]; then
    exit 1
fi

# Sections we want to overwrite from the generated file
SECTIONS=(
    "Colors:Button"
    "Colors:Complementary"
    "Colors:Selection"
    "Colors:Tooltip"
    "Colors:View"
    "Colors:Window"
    "WM"
)

# Use kwriteconfig6 if available, otherwise do manual merge
if command -v kwriteconfig6 &>/dev/null; then
    # Parse the generated file and write each key
    current_section=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
        elif [[ -n "$current_section" && "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            for s in "${SECTIONS[@]}"; do
                if [[ "$current_section" == "$s" ]]; then
                    kwriteconfig6 --file "$TARGET" --group "$current_section" --key "$key" "$val"
                    break
                fi
            done
        fi
    done < "$COLORS"
else
    # Fallback: just copy the generated file (loses user settings)
    cp "$COLORS" "$TARGET"
fi
