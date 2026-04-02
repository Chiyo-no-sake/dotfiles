#!/usr/bin/env bash
# Scrollbar indicator for Hyprland's scrolling layout.
# Outputs Pango markup with ▬ characters (U+25AC, black rectangle).
# These connect seamlessly at small sizes unlike full block █.

trap 'exit 0' PIPE TERM INT

get_scrollbar() {
    python3 - 2>/dev/null <<'PYEOF'
import json, subprocess, sys, signal
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

def hyprctl_json(cmd):
    r = subprocess.run(["hyprctl", cmd, "-j"], capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 else None

workspace = hyprctl_json("activeworkspace")
if not workspace or workspace.get("tiledLayout") != "scrolling":
    print(json.dumps({"text": "", "tooltip": "", "class": "hidden"}))
    sys.exit(0)

ws_id = workspace["id"]
mon_id = workspace.get("monitorID", 0)

monitors = hyprctl_json("monitors")
mon = next((m for m in (monitors or []) if m["id"] == mon_id), None)
if not mon:
    print(json.dumps({"text": "", "tooltip": "", "class": "hidden"}))
    sys.exit(0)

clients = hyprctl_json("clients")
ws_wins = [c for c in (clients or [])
           if c["workspace"]["id"] == ws_id
           and not c["floating"] and c["mapped"] and not c["hidden"]]

if not ws_wins:
    print(json.dumps({"text": "", "tooltip": "", "class": "hidden"}))
    sys.exit(0)

tape_left = min(w["at"][0] for w in ws_wins)
tape_right = max(w["at"][0] + w["size"][0] for w in ws_wins)
tape_width = tape_right - tape_left

scale = mon.get("scale", 1.0) or 1.0
vp_left = mon["x"]
vp_width = mon["width"] / scale

if tape_width <= vp_width * 1.05:
    print(json.dumps({"text": "", "tooltip": "", "class": "hidden"}))
    sys.exit(0)

# Character count — ▬ at ~7pt is roughly 6px wide
bar_len = int(mon["width"] / scale / 6)

thumb_ratio = vp_width / tape_width
thumb_pos_ratio = (vp_left - tape_left) / tape_width
thumb_size = max(3, int(thumb_ratio * bar_len))
thumb_start = max(0, min(int(thumb_pos_ratio * bar_len), bar_len - thumb_size))
thumb_end = thumb_start + thumb_size

# ▬ (U+25AC) — black rectangle, connects well at small sizes
CHAR = "\u25ac"
track_color = "#444444"
thumb_color = "#bbbbbb"

parts = []
if thumb_start > 0:
    parts.append(f'<span foreground="{track_color}">{CHAR * thumb_start}</span>')
parts.append(f'<span foreground="{thumb_color}">{CHAR * thumb_size}</span>')
remaining = bar_len - thumb_end
if remaining > 0:
    parts.append(f'<span foreground="{track_color}">{CHAR * remaining}</span>')

text = "".join(parts)
tooltip = f"{len(ws_wins)} windows \u2022 {tape_width:.0f}px tape"

print(json.dumps({"text": text, "tooltip": tooltip, "class": "visible"}))
PYEOF
}

if [[ "$1" == "--listen" ]]; then
    get_scrollbar
    socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null | while read -r line; do
        case "$line" in
            workspace*|openwindow*|closewindow*|movewindow*|activewindow*|fullscreen*)
                get_scrollbar || exit 0
                ;;
        esac
    done
else
    get_scrollbar
fi
