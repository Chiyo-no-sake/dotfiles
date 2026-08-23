#!/usr/bin/env bash
# hypr-colors-boost.sh — matugen post_hook for the hyprland colors template.
#
# Applies the same vibrance boost (x1.75, saturation-only) the quickshell
# bar (Color.qml), the opencode theme hook, and the aoe theme hook use, so
# hyprland's accent-colored surfaces — above all the active window border
# (primary→tertiary 45deg gradient in hyprland.conf) — match the bar's
# boosted underlines and panel gradients exactly.
#
# Rewrites $primary/$secondary/$tertiary (both rgb() and *Alpha forms) in
# ~/.config/hypr/colors.conf in place. Callers (theme-toggle.sh,
# wallpaper-cycle.sh) run `hyprctl reload` after matugen completes, which
# picks the boosted values up. Always exits 0.
set -uo pipefail

CONF="$HOME/.config/hypr/colors.conf"
[[ -f "$CONF" ]] || exit 0

python3 - "$CONF" <<'PYEOF' 
import colorsys, pathlib, re, sys
p = pathlib.Path(sys.argv[1])

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
    return "%02x%02x%02x" % (round(r2*255), round(g2*255), round(b2*255))

BOOST = {"primary", "secondary", "tertiary"}
out = []
for line in p.read_text().splitlines():
    # forms: $primary = rgb(c2c1ff)   |   $primaryAlpha = c2c1ff
    m = re.match(r"^\$(\w+?)(Alpha)? = (?:rgb\()?([0-9a-fA-F]{6})\)?\s*$", line)
    if m and m.group(1) in BOOST:
        name, suffix, hexv = m.group(1), m.group(2) or "", boost(m.group(3))
        if suffix:
            out.append(f"${name}{suffix} = {hexv}")
        else:
            out.append(f"${name} = rgb({hexv})")
    else:
        out.append(line)
p.write_text("\n".join(out) + "\n")
PYEOF
exit 0
