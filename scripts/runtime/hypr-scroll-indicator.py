#!/usr/bin/python3
"""
Hyprland scrolling layout indicator — a thin bottom bar showing viewport
position on the window tape, like a browser scrollbar.

Uses GTK4 + gtk4-layer-shell for a pixel-perfect overlay.
Requires: LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so.0
"""

import argparse
import json
import math
import subprocess
import threading
import socket
import os
import signal

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell as LayerShell

# ── CLI args ────────────────────────────────────────────────
_parser = argparse.ArgumentParser(description="Hyprland scroll indicator bar")
_parser.add_argument("--bar-height", type=int, default=12, help="Height of the bar in px (default: 12)")
_parser.add_argument("--thumb-radius", type=int, default=6, help="Corner radius of thumb/track in px (default: 6)")
_parser.add_argument("--margin-bottom", type=int, default=12, help="Bottom margin in px (default: 12)")
_parser.add_argument("--margin-side", type=int, default=64, help="Left/right margin in px (default: 64)")
_parser.add_argument("--colors-file", type=str, default="~/.config/hypr/colors.conf", help="Path to matugen colors file")
_args = _parser.parse_args()

# ── Config ──────────────────────────────────────────────────
BAR_HEIGHT = _args.bar_height
THUMB_RADIUS = _args.thumb_radius
MARGIN_BOTTOM = _args.margin_bottom
MARGIN_SIDE = _args.margin_side
COLORS_FILE = os.path.expanduser(_args.colors_file)
# ────────────────────────────────────────────────────────────


def parse_hypr_colors(path):
    """Read matugen-generated colors.conf and return a dict of name→(r,g,b)."""
    colors = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("$") and "= rgb(" in line:
                    name, _, val = line.partition("=")
                    name = name.strip().lstrip("$")
                    hex_str = val.strip().removeprefix("rgb(").removesuffix(")")
                    r = int(hex_str[0:2], 16) / 255
                    g = int(hex_str[2:4], 16) / 255
                    b = int(hex_str[4:6], 16) / 255
                    colors[name] = (r, g, b)
    except Exception:
        pass
    return colors


def get_theme_colors():
    """Return (track_rgba, thumb_rgba) from the theme."""
    c = parse_hypr_colors(COLORS_FILE)
    # Track: darkened primary (fully opaque)
    pr, pg, pb = c.get("primary", (0.57, 0.84, 0.62))
    # Thumb: full primary (fully opaque)
    return (pr * 0.15, pg * 0.15, pb * 0.15, 1.0), (pr, pg, pb, 1.0)

state = None         # target (start_frac, end_frac) or None
display_state = None # currently displayed (start, end) — animated towards state
win = None
drawing_area = None
anim_id = None       # GLib timeout source id
TRACK_COLOR, THUMB_COLOR = get_theme_colors()

ANIM_DURATION_MS = 600  # overridden at startup from hyprland config
ANIM_TICK_MS = 16       # ~60fps


_monitors_cache = None


def get_scroll_state():
    global _monitors_cache

    # Single hyprctl call via unix socket — much faster than subprocess
    try:
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        sock_path = f"{runtime}/hypr/{sig}/.socket.sock"

        def hyprctl_sock(cmd):
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(1)
            s.connect(sock_path)
            s.send(f"j/{cmd}".encode())
            chunks = []
            while True:
                data = s.recv(8192)
                if not data:
                    break
                chunks.append(data)
            s.close()
            return json.loads(b"".join(chunks))

        workspace = hyprctl_sock("activeworkspace")
    except Exception:
        return None

    if not workspace or workspace.get("tiledLayout") != "scrolling":
        return None

    ws_id = workspace["id"]
    mon_id = workspace.get("monitorID", 0)

    try:
        if _monitors_cache is None:
            _monitors_cache = hyprctl_sock("monitors")
        mon = next((m for m in _monitors_cache if m["id"] == mon_id), None)
        if not mon:
            return None

        clients = hyprctl_sock("clients")
    except Exception:
        return None

    ws_wins = [
        c for c in (clients or [])
        if c["workspace"]["id"] == ws_id
        and not c["floating"] and c["mapped"] and not c["hidden"]
    ]
    if not ws_wins:
        return None

    tape_left = min(w["at"][0] for w in ws_wins)
    tape_right = max(w["at"][0] + w["size"][0] for w in ws_wins)
    tape_width = tape_right - tape_left

    scale = mon.get("scale", 1.0) or 1.0
    vp_left = mon["x"]
    vp_width = mon["width"] / scale

    if tape_width <= vp_width * 1.05:
        return None

    start = max(0.0, (vp_left - tape_left) / tape_width)
    end = min(1.0, start + vp_width / tape_width)
    return (start, end)


def parse_bezier_from_config():
    """Read the workspace animation bezier and speed from hyprland.conf."""
    try:
        conf = os.path.expanduser("~/.config/hypr/hyprland.conf")
        beziers = {}
        ws_bezier = "default"
        ws_speed = 6
        with open(conf) as f:
            for line in f:
                line = line.strip()
                if line.startswith("bezier") and "=" in line:
                    _, _, rest = line.partition("=")
                    parts = [p.strip() for p in rest.split(",")]
                    if len(parts) == 5:
                        name = parts[0]
                        beziers[name] = tuple(float(x) for x in parts[1:])
                if line.startswith("animation") and "workspaces" in line:
                    parts = [p.strip() for p in line.partition("=")[2].split(",")]
                    if len(parts) >= 4:
                        ws_speed = int(parts[2])
                        ws_bezier = parts[3]
        points = beziers.get(ws_bezier, (0.25, 1.0, 0.5, 1.0))
        duration_ms = ws_speed * 100
        return points, duration_ms
    except Exception:
        pass
    return (0.25, 1.0, 0.5, 1.0), 600


def cubic_bezier_y(t, x1, y1, x2, y2):
    """Evaluate a cubic bezier curve's Y value at parameter t."""
    # The bezier is defined as B(t) = (Bx(t), By(t))
    # Bx(t) = 3*(1-t)^2*t*x1 + 3*(1-t)*t^2*x2 + t^3
    # By(t) = 3*(1-t)^2*t*y1 + 3*(1-t)*t^2*y2 + t^3
    return 3 * (1 - t)**2 * t * y1 + 3 * (1 - t) * t**2 * y2 + t**3


def cubic_bezier_x(t, x1, x2):
    return 3 * (1 - t)**2 * t * x1 + 3 * (1 - t) * t**2 * x2 + t**3


def bezier_ease(progress, x1, y1, x2, y2):
    """Given a time progress [0,1], find the eased value using cubic bezier.
    Uses Newton's method to find t where Bx(t) = progress, then returns By(t)."""
    t = progress  # initial guess
    for _ in range(8):  # Newton iterations
        bx = cubic_bezier_x(t, x1, x2)
        dx = 3 * (1 - t)**2 * x1 + 6 * (1 - t) * t * (x2 - x1) + 3 * t**2 * (1 - x2)
        if abs(dx) < 1e-6:
            break
        t -= (bx - progress) / dx
        t = max(0, min(1, t))
    return cubic_bezier_y(t, x1, y1, x2, y2)


# Read the bezier curve and duration from hyprland config at startup
_bezier_points, ANIM_DURATION_MS = parse_bezier_from_config()


def ease_in_out(progress):
    """Ease using the same bezier curve as Hyprland workspace animations."""
    return bezier_ease(progress, *_bezier_points)


def lerp(a, b, t):
    return a + (b - a) * t


def start_animation():
    """Kick off the animation tick loop if not already running."""
    global anim_id
    if anim_id is not None:
        GLib.source_remove(anim_id)
        anim_id = None

    import time
    anim_start = [time.monotonic()]
    origin = [display_state]  # snapshot where we're animating from

    def tick():
        global display_state, anim_id, state
        if state is None or origin[0] is None:
            anim_id = None
            return False

        elapsed = time.monotonic() - anim_start[0]
        progress = min(1.0, elapsed / (ANIM_DURATION_MS / 1000))
        t = ease_in_out(progress)

        display_state = (
            lerp(origin[0][0], state[0], t),
            lerp(origin[0][1], state[1], t),
        )

        if drawing_area:
            drawing_area.queue_draw()

        if progress >= 1.0:
            display_state = state
            anim_id = None
            return False  # stop
        return True  # continue

    anim_id = GLib.timeout_add(ANIM_TICK_MS, tick)


def draw_func(_area, cr, width, height):
    global display_state
    if not display_state:
        return

    import cairo
    start_frac, end_frac = display_state

    # Clear to fully transparent first
    cr.set_operator(cairo.OPERATOR_SOURCE)

    # Track
    cr.set_source_rgba(*TRACK_COLOR)
    rounded_rect(cr, 0, 0, width, height, THUMB_RADIUS)
    cr.fill()

    # Thumb — painted with SOURCE operator so alpha is written directly
    thumb_x = start_frac * width
    thumb_w = (end_frac - start_frac) * width
    cr.set_source_rgba(*THUMB_COLOR)
    rounded_rect(cr, thumb_x, 0, thumb_w, height, THUMB_RADIUS)
    cr.fill()


def rounded_rect(cr, x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    cr.new_path()
    cr.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)
    cr.arc(x + w - r, y + r, r, 1.5 * math.pi, 2 * math.pi)
    cr.arc(x + w - r, y + h - r, r, 0, 0.5 * math.pi)
    cr.arc(x + r, y + h - r, r, 0.5 * math.pi, math.pi)
    cr.close_path()


def refresh():
    global state, display_state, win, drawing_area
    new_state = get_scroll_state()

    if win is None:
        return False

    if new_state:
        LayerShell.set_exclusive_zone(win, BAR_HEIGHT + MARGIN_BOTTOM)
        win.set_visible(True)

        if display_state is None:
            # First show — snap immediately, no animation
            display_state = new_state
            state = new_state
            if drawing_area:
                drawing_area.queue_draw()
        else:
            state = new_state
            start_animation()
    else:
        state = None
        display_state = None
        LayerShell.set_exclusive_zone(win, 0)
        win.set_visible(False)

    return False


def ipc_listener():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sock_path = f"{runtime}/hypr/{sig}/.socket2.sock"

    while True:
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(sock_path)
            buf = b""
            while True:
                data = sock.recv(4096)
                if not data:
                    break
                buf += data
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    event = line.decode("utf-8", errors="replace")
                    if any(event.startswith(e) for e in (
                        "workspace", "openwindow", "closewindow",
                        "movewindow", "activewindow", "fullscreen",
                    )):
                        GLib.idle_add(refresh)
        except Exception:
            pass
        import time
        time.sleep(1)


def on_activate(app):
    global win, drawing_area

    win = Gtk.ApplicationWindow(application=app)

    # Layer shell — must be before present()
    LayerShell.init_for_window(win)
    LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
    LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
    LayerShell.set_anchor(win, LayerShell.Edge.LEFT, True)
    LayerShell.set_anchor(win, LayerShell.Edge.RIGHT, True)
    LayerShell.set_margin(win, LayerShell.Edge.BOTTOM, MARGIN_BOTTOM)
    LayerShell.set_margin(win, LayerShell.Edge.LEFT, MARGIN_SIDE)
    LayerShell.set_margin(win, LayerShell.Edge.RIGHT, MARGIN_SIDE)
    LayerShell.set_exclusive_zone(win, 0)  # toggled dynamically in refresh()
    LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
    LayerShell.set_namespace(win, "hypr-scroll-indicator")

    # Drawing area
    drawing_area = Gtk.DrawingArea()
    drawing_area.set_content_height(BAR_HEIGHT)
    drawing_area.set_draw_func(draw_func)
    win.set_child(drawing_area)

    # Transparent background
    css = Gtk.CssProvider()
    css.load_from_string(
        "window, window.background { background: transparent; }"
    )
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(),
        css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    win.present()

    # Initial state
    refresh()

    # IPC listener thread
    t = threading.Thread(target=ipc_listener, daemon=True)
    t.start()


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    app = Gtk.Application(application_id="dev.hypr.scroll-indicator")
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()
