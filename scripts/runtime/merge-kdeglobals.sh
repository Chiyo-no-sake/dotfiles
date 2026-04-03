#!/bin/bash
# Merge matugen-generated KDE colors into kdeglobals without losing user settings
# Usage: merge-kdeglobals.sh <generated-colors-file>

COLORS="$1"
TARGET="$HOME/.config/kdeglobals"

if [ ! -f "$COLORS" ]; then
    exit 1
fi

# Sections to overwrite from the generated file
SECTIONS=(
    "Colors:Button"
    "Colors:Complementary"
    "Colors:Header"
    "Colors:Header:Selection"
    "Colors:Selection"
    "Colors:Tooltip"
    "Colors:View"
    "Colors:Window"
    "General"
    "WM"
)

# Parse the generated file and write each key using kwriteconfig6
current_section=""
while IFS= read -r line; do
    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
        current_section="${BASH_REMATCH[1]}"
    elif [[ -n "$current_section" && "$line" =~ ^([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        for s in "${SECTIONS[@]}"; do
            if [[ "$current_section" == "$s" ]]; then
                kwriteconfig6 --file "$TARGET" --group "$current_section" --key "$key" -- "$val"
                break
            fi
        done
    fi
done < "$COLORS"

# Clear icon and thumbnail caches so icons pick up new accent
rm -f ~/.cache/icon-cache.kcache
rm -rf ~/.cache/thumbnails/

# Emit D-Bus signals to force all running KDE apps to reload
# type 0 = PaletteChanged, type 2 = StyleChanged, type 4 = IconChanged
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:2 int32:0
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:4 int32:0

