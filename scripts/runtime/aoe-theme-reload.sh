#!/usr/bin/env bash
# aoe-theme-reload.sh — matugen post_hook for the aoe (Agent of Empires)
# theme. Runs after every matugen regeneration:
#   1. saturation-boosts the accent-family keys in themes/matugen.toml
#      (same vibrance formula as Color.qml in the quickshell bar and the
#      opencode theme hook; matugen's tone-80 dark accents are pastel)
#   2. PATCHes the running daemon's /api/theme so the web dashboard (and
#      anything attached to the daemon) re-themes live; TUI instances pick
#      the regenerated file up on their next launch
# Always exits 0: theme reload must never fail the matugen run.
set -uo pipefail

THEME="$HOME/.config/agent-of-empires/themes/matugen.toml"
TOKEN_FILE="$HOME/.config/agent-of-empires/serve.token"
PORT="${AOE_SERVE_PORT:-8080}"

# ---- 1. vibrance boost (accent-family keys only) ----
python3 - "$THEME" <<'PYEOF' 2>/dev/null || true
import colorsys, pathlib, re, sys
p = pathlib.Path(sys.argv[1])
if not p.exists():
    sys.exit(0)
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
BOOST = {"title", "search", "accent", "help_key", "terminal_border",
         "terminal_active", "branch", "unread", "diff_header"}
out = []
for line in p.read_text().splitlines():
    m = re.match(r'^(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"$', line)
    if m and m.group(1) in BOOST:
        out.append(f'{m.group(1)} = "{boost(m.group(2))}"')
    else:
        out.append(line)
p.write_text("\n".join(out) + "\n")
PYEOF

# ---- 2. live PATCH to the daemon, if running ----
if [[ -s "$TOKEN_FILE" ]] && command -v curl >/dev/null 2>&1; then
    token="$(tr -d ' \t\r\n' <"$TOKEN_FILE")"
    # Fire-and-forget with a short timeout; failures are harmless (daemon
    # not up, theme not yet known to it — next PATCH after its restart
    # catches up, and TUI startups read the file directly).
    curl -s -m 2 -X PATCH "http://127.0.0.1:$PORT/api/theme" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{"name":"matugen"}' >/dev/null 2>&1 || true
fi

exit 0
