#!/usr/bin/env bash
# Waybar clipboard module (cliphist): entry count + recent history in tooltip.
# Click actions are wired in the waybar config to scripts/runtime/clipboard-history.sh
#
# NOTE: absolute path — waybar inherits the session PATH, which does not
# include ~/.local/share/bin.

CLIPHIST="$HOME/dotfiles/.local/share/bin/cliphist"

LIST="$("$CLIPHIST" list 2>/dev/null || true)"
count="$(printf '%s\n' "$LIST" | wc -l | tr -d ' ')"
[[ -z "${LIST//[$' \t\n']/}" ]] && count=0

if (( count == 0 )); then
    echo '{"text": "󰅍", "class": "clipboard", "tooltip": "Clipboard history is empty"}'
    exit 0
fi

tooltip="Clipboard history (${count} entries) — click to pick"
while IFS=$'\t' read -r _id preview; do
    # truncate to 60 chars, drop control chars (odd binary entries leak them),
    # pango-escape (& < >)
    line="$(printf '%s' "$preview" | cut -c1-60 | tr -d '\000-\037\177' | sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
    tooltip+="\\n• ${line}"
done < <(printf '%s\n' "$LIST" | head -8)

# JSON-escape backslashes and quotes
tooltip="$(printf '%s' "$tooltip" | sed -e 's/\\/\\\\/g; s/"/\\"/g')"

printf '{"text": "󰅍 %s", "class": "clipboard", "tooltip": "%s"}\n' "$count" "$tooltip"
