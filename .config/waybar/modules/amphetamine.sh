#!/usr/bin/env bash
# Waybar wrapper around amphetamine.sh (hypridle keep-awake).
# Left-click toggles an indefinite session; right-click adds 60 timed
# minutes (repeat right-clicks stack).

ENGINE="$HOME/dotfiles/scripts/runtime/amphetamine.sh"

# fa-eye / fa-eye-slash, as escapes so the glyphs survive any re-encoding
ICON_ON=$'\uf06e'
ICON_OFF=$'\uf070'

case "${1:-}" in
    toggle) "$ENGINE" toggle >/dev/null 2>&1 ;;
    timer)  "$ENGINE" bump 60 >/dev/null 2>&1 ;;
esac

status="$("$ENGINE" status)"

case "$status" in
    off)
        printf '{"text": "%s", "class": "off", "tooltip": "Amphetamine: off — idle timeouts active\\nclick: stay awake · right-click: +60 min"}\n' "$ICON_OFF"
        ;;
    inf)
        printf '{"text": "%s", "class": "on", "tooltip": "Amphetamine: staying awake until toggled off\\nclick: back to normal"}\n' "$ICON_ON"
        ;;
    *)
        mins=$(( (status + 59) / 60 ))
        printf '{"text": "%s %sm", "class": "on", "tooltip": "Amphetamine: staying awake for %s more min\\nright-click: +60 min · click: back to normal"}\n' "$ICON_ON" "$mins" "$mins"
        ;;
esac
