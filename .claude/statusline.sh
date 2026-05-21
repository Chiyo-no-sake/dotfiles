#!/usr/bin/env bash
# Claude Code rich statusline.
#
# Layout:    <starship prompt>           │ [████████▎░░░░░░░] 53%! · 8.4K tok
#            └── dir / git / lang ──┘<pad>└──── context bar (anchored right) ────┘
#
# Input:  JSON from Claude on stdin (cwd, model, context_window{used_percentage, current_usage}).
# Output: one ANSI-colored line, padded so the context bar sits flush against the
#         right terminal edge. When the left segment would overflow, it is
#         truncated from the START with "…" so the bar always stays visible.
# Must never fail — always print something.

set -u
input=$(cat)

# Resolve real location of this script even through Stow's symlink chain, so
# statusline.toml sits next to it regardless of where Claude invoked from.
SCRIPT="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT" ]; do SCRIPT="$(readlink -f "$SCRIPT")"; done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"
STARSHIP_CFG="${SCRIPT_DIR}/statusline.toml"

# ---------- Single python pass: parse JSON, render bar, run starship, compose ----------
# Doing everything in one interpreter keeps us at one fork (was already python+bash;
# starship is now a subprocess of python instead of a peer of it). JSON arrives via
# env var because the heredoc owns python's stdin.
CLAUDE_STATUSLINE_INPUT="$input" \
STARSHIP_CFG="$STARSHIP_CFG" \
python3 - <<'PYEOF'
import os, sys, json, re, subprocess, unicodedata

# --- ANSI palette (256-color, cohesive on xterm-kitty / truecolor) ---
RESET  = "\033[0m"
BOLD   = "\033[1m"
DIM    = "\033[2m"
GREEN  = "\033[38;5;120m"
ORANGE = "\033[38;5;215m"
RED    = "\033[38;5;203m"

try:
    d = json.loads(os.environ.get("CLAUDE_STATUSLINE_INPUT", "") or "{}")
except Exception:
    d = {}

# --- cwd ---
home = os.path.expanduser("~")
cwd  = d.get("cwd") or (d.get("workspace") or {}).get("current_dir") or home
if not os.path.isdir(cwd):
    cwd = home

# --- context window ---
cw = d.get("context_window") or {}
raw_pct = cw.get("used_percentage")
try:
    real = float(raw_pct) if raw_pct is not None else -1.0
except (TypeError, ValueError):
    real = -1.0

u = cw.get("current_usage") or {}
keys = ("input_tokens", "output_tokens",
        "cache_creation_input_tokens", "cache_read_input_tokens")
toks = int(sum(v for v in (u.get(k) for k in keys) if isinstance(v, (int, float))))

# --- bar segment ---
if real < 0:
    bar_line = f"{DIM}[{'░'*16}] --%{RESET}"
else:
    real = max(0.0, min(100.0, real))
    # Past ~50% real usage, model quality drops — treat 50% as "full" on the
    # bar so the visual budget matches the usable budget. Tokens stay true.
    disp   = min(real * 2.0, 100.0)
    WIDTH  = 16
    filled = max(0, min(WIDTH, int(round(disp / 100.0 * WIDTH))))
    bar    = "█" * filled + "░" * (WIDTH - filled)

    # Color keyed to REAL pct (not rescaled), matches sartiq thresholds.
    color = GREEN if real < 30 else ORANGE if real < 40 else RED
    if   real > 70: suffix = "!!!"
    elif real > 60: suffix = "!!"
    elif real > 50: suffix = "!"
    else:           suffix = ""

    def fmt_tokens(n: int) -> str:
        if n < 1000:      return str(n)
        if n < 10_000:    return f"{n/1000:.1f}K"
        if n < 1_000_000: return f"{n//1000}K"
        return f"{n/1_000_000:.1f}M"

    tok_seg = f" {DIM}· {fmt_tokens(toks)} tok{RESET}" if toks > 0 else ""
    pct_int = int(round(disp))
    bar_line = (
        f"{DIM}[{RESET}"
        f"{BOLD}{color}{bar}{RESET}"
        f"{DIM}]{RESET} "
        f"{BOLD}{color}{pct_int}%{suffix}{RESET}"
        f"{tok_seg}"
    )

# --- starship prompt (dir + git + languages) ---
# STARSHIP_SHELL=nu emits raw ANSI without bash/zsh prompt-escape wrappers
# (\[..\] / %{..%}), which would render as literal characters in a statusline.
starship_segment = ""
cfg = os.environ.get("STARSHIP_CFG", "")
try:
    if cfg and os.path.isfile(cfg):
        env = os.environ.copy()
        env["STARSHIP_CONFIG"] = cfg
        env["STARSHIP_SHELL"]  = "nu"
        r = subprocess.run(
            ["starship", "prompt"],
            cwd=cwd, env=env,
            capture_output=True, text=True, timeout=2.0,
        )
        starship_segment = (r.stdout or "").rstrip("\n")
except Exception:
    starship_segment = ""

# --- terminal width detection ---
# Claude Code does not pass width in the JSON, so we probe. We try every
# possible fd in case one is a tty, then /dev/tty directly, then $COLUMNS.
# Returns 0 if unknowable — the caller treats that as "skip padding/truncation".
def term_cols() -> int:
    for k in ("terminal_width", "cols", "columns"):
        v = d.get(k)
        if isinstance(v, int) and v > 0:
            return v
    for fd in (1, 2, 0):
        try:
            sz = os.get_terminal_size(fd)
            if sz.columns > 0:
                return sz.columns
        except OSError:
            pass
    try:
        import struct, fcntl, termios
        with open("/dev/tty") as t:
            _, w, _, _ = struct.unpack(
                "HHHH",
                fcntl.ioctl(t.fileno(), termios.TIOCGWINSZ, b"\0" * 8),
            )
            if w > 0:
                return w
    except Exception:
        pass
    try:
        v = int(os.environ.get("COLUMNS", "0"))
        if v > 0:
            return v
    except Exception:
        pass
    return 0

cols = term_cols()

# --- ANSI-aware width + front-truncation ---
# Match CSI escape sequences (color/style). We don't strip them when truncating —
# we only skip visible characters, so colors after the cut still render.
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

def char_width(c: str) -> int:
    # Wide East-Asian / fullwidth chars take 2 cells; nerd-font glyphs are
    # private-use codepoints and report as 'N'/'A' → counted as 1, which is
    # how Kitty (and most terminals) actually render them.
    return 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1

def visible_len(s: str) -> int:
    return sum(char_width(c) for c in ANSI.sub("", s))

def truncate_front(s: str, budget: int) -> str:
    """Drop visible chars from the START of `s` until display width <= budget,
    keeping every ANSI escape in place so styling after the cut still renders.
    Prepends '…' as a clipping hint."""
    if budget <= 1:
        return "…"
    plain_w = visible_len(s)
    target  = budget - 1  # reserve one cell for the leading ellipsis
    if plain_w <= target:
        return s
    drop = plain_w - target
    out, dropped, i = [], 0, 0
    while i < len(s):
        m = ANSI.match(s, i)
        if m:
            out.append(s[i:m.end()])  # always preserve escapes
            i = m.end()
            continue
        if dropped < drop:
            dropped += char_width(s[i])
            i += 1
        else:
            out.append(s[i])
            i += 1
    return "…" + "".join(out)

# --- compose final line ---
SEP_VISIBLE = 3  # " │ "
SEP = f"{DIM}│{RESET}"
right   = bar_line
right_w = visible_len(right)
left    = starship_segment
left_w  = visible_len(left)

def emit(s: str) -> None:
    sys.stdout.write(s + "\n")

if not left:
    # No starship segment — just print the bar (right-anchored if cols known).
    if cols > 0 and right_w < cols:
        emit(" " * (cols - right_w) + right)
    else:
        emit(right)
    sys.exit(0)

if cols <= 0:
    # Width unknown: fall back to current behavior (no padding, no truncation).
    emit(f"{left} {SEP} {right}")
    sys.exit(0)

total = left_w + SEP_VISIBLE + right_w
if total <= cols:
    # Right-anchor by padding BEFORE the separator so "│ bar" stays glued together.
    pad = cols - total
    emit(f"{left}{' ' * pad} {SEP} {right}")
else:
    # Left would overflow — truncate from the front, keep the bar intact.
    budget = cols - SEP_VISIBLE - right_w
    if budget < 1:
        # Pathological: bar alone exceeds terminal width. Just print the bar.
        emit(right)
    else:
        emit(f"{truncate_front(left, budget)} {SEP} {right}")
PYEOF
