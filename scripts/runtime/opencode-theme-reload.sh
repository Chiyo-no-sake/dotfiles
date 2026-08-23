#!/usr/bin/env bash
# opencode-theme-reload.sh — signal running opencode TUIs after matugen
# regenerates themes/matugen.json. The TUI re-reads its theme files on
# SIGUSR2 (packages/tui/src/context/theme.tsx: subscribeRefresh).
#
# Wired as the matugen [templates.opencode] post_hook, so every theme
# regeneration (wallpaper cycle, theme toggle, manual run) live-reloads
# every TUI without touching theme-toggle.sh or wallpaper-cycle.sh.
#
# CRITICAL — skip ancestors: the opencode session that TRIGGERED this
# matugen run (a terminal inside a TUI, or an agent running the script)
# must never be signaled: SIGUSR2 arriving while that session is executing
# a tool aborts the in-flight command. Ancestor sessions pick the
# regenerated theme the next time they render/restart instead.
set -uo pipefail

# Vibrance boost (same formula as Color.qml in the quickshell bar):
# matugen's tone-80 dark accents are pastel; raise saturation only, never
# value, so light-mode accents keep their dark-tone contrast. Rewrites the
# accent defs in place before signaling the TUIs.
python3 - "$HOME/.config/opencode/themes/matugen.json" <<'PYEOF' 2>/dev/null || true
import colorsys, json, sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.exists():
    sys.exit(0)
data = json.loads(p.read_text())
def boost(hexc):
    h = hexc.lstrip("#")
    if len(h) != 6:
        return hexc
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    hh, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s <= 0:
        return hexc
    s = min(0.85, max(s * 1.75, 0.45))
    r2, g2, b2 = colorsys.hsv_to_rgb(hh, s, v)
    return "#%02x%02x%02x" % (round(r2*255), round(g2*255), round(b2*255))
for key in ("accent", "accent2", "accent3"):
    val = data.get("defs", {}).get(key)
    if isinstance(val, str) and val.startswith("#"):
        data["defs"][key] = boost(val)
p.write_text(json.dumps(data, indent=2) + "\n")
PYEOF

# Walk /proc parents, collecting opencode PIDs to spare.
skip=" "
pid=$$
while [ "$pid" -gt 1 ] 2>/dev/null; do
  line="$(ps -o ppid=,comm= -p "$pid" 2>/dev/null)" || break
  [ -z "$line" ] && break
  read -r ppid comm <<<"$line"
  [ -z "${ppid:-}" ] && break
  [ "$comm" = "opencode" ] && skip="$skip$pid "
  pid="$ppid"
done

count=0
for opc in $(pgrep -x opencode 2>/dev/null); do
  case "$skip" in *" $opc "*) continue ;; esac
  kill -USR2 "$opc" 2>/dev/null || true
  count=$((count + 1))
done

# Exit 0 always: a missing pgrep or a race on a dying PID must never
# fail the matugen run that invoked us.
exit 0
