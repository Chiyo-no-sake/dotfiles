#!/usr/bin/python3
"""
Hyprland audio visualizer — renders cava output on the background Wayland layer,
behind all windows but above the wallpaper.

Uses GTK4 + gtk4-layer-shell + cava raw output.
Requires: LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so.0
"""

import argparse
import math
import os
import signal
import subprocess
import threading

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell as LayerShell

# ── CLI args ────────────────────────────────────────────────
_parser = argparse.ArgumentParser(description="Hyprland cava visualizer")
_parser.add_argument("--bars", type=int, default=50, help="Number of bars (default: 50)")
_parser.add_argument("--framerate", type=int, default=0, help="Framerate (default: auto-detect from monitor)")
_parser.add_argument("--height-pct", type=float, default=20, help="Height as %% of monitor (default: 20)")
_parser.add_argument("--opacity", type=float, default=0.55, help="Bar opacity (default: 0.55)")
_parser.add_argument("--gap", type=float, default=4, help="Gap between bars in px (default: 4)")
_parser.add_argument("--roundness", type=float, default=0.5, help="Bar corner roundness 0-1 (default: 0.5)")
_parser.add_argument("--mirror", action="store_true", default=True, help="Mirror bars vertically (default: true)")
_parser.add_argument("--no-mirror", action="store_true", help="Disable vertical mirroring")
_parser.add_argument("--monstercat", action="store_true", default=True, help="Monstercat smoothing (default: true)")
_parser.add_argument("--noise-reduction", type=float, default=0.50, help="Noise reduction (default: 0.50)")
_parser.add_argument("--colors-file", type=str, default="~/.config/hypr/colors.conf",
                      help="Path to matugen colors file")
_args = _parser.parse_args()
if _args.no_mirror:
    _args.mirror = False

COLORS_FILE = os.path.expanduser(_args.colors_file)

def detect_refresh_rate():
    """Read the active monitor's refresh rate from Hyprland."""
    try:
        import json, socket
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        sock_path = f"{runtime}/hypr/{sig}/.socket.sock"
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1)
        s.connect(sock_path)
        s.send(b"j/monitors")
        chunks = []
        while True:
            data = s.recv(8192)
            if not data:
                break
            chunks.append(data)
        s.close()
        monitors = json.loads(b"".join(chunks))
        if monitors:
            return int(monitors[0].get("refreshRate", 60))
    except Exception:
        pass
    return 60

def detect_power_profile():
    """Read active power profile via D-Bus."""
    try:
        result = subprocess.run(
            ["busctl", "get-property", "net.hadess.PowerProfiles",
             "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"],
            capture_output=True, text=True, timeout=2,
        )
        return result.stdout.strip().split('"')[1]
    except Exception:
        return "balanced"

def apply_power_scaling(framerate):
    """Return fixed framerate based on power profile."""
    profile = detect_power_profile()
    if profile == "power-saver":
        return 40
    elif profile == "balanced":
        return 60
    return 90  # performance

if _args.framerate <= 0:
    _args.framerate = apply_power_scaling(detect_refresh_rate())

# ── State ──────────────────────────────────────────────────
bar_values = [0.0] * _args.bars
win = None
drawing_area = None
_gradient_phase = 0.0  # 0..1, shifts the gradient horizontally
GRADIENT_SPEED = 0.15  # full cycles per second


def parse_hypr_colors(path):
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
    c = parse_hypr_colors(COLORS_FILE)
    primary = c.get("primary", (0.95, 0.75, 0.43))
    secondary = c.get("secondary", (0.90, 0.74, 0.75))
    tertiary = c.get("tertiary", (0.71, 0.81, 0.64))
    return primary, secondary, tertiary


FG_PRIMARY, FG_SECONDARY, FG_TERTIARY = get_theme_colors()


def reload_colors():
    global FG_PRIMARY, FG_SECONDARY, FG_TERTIARY
    FG_PRIMARY, FG_SECONDARY, FG_TERTIARY = get_theme_colors()


def interpolate_color(c1, c2, t):
    return (
        c1[0] + (c2[0] - c1[0]) * t,
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
    )


def smooth_curve(cr, points):
    """Draw a smooth curve through points using cubic bezier splines."""
    if len(points) < 2:
        return
    cr.move_to(*points[0])
    if len(points) == 2:
        cr.line_to(*points[1])
        return
    for i in range(1, len(points) - 1):
        x0, y0 = points[i - 1]
        x1, y1 = points[i]
        x2, y2 = points[i + 1]
        cp1x = x0 + (x1 - x0) * 0.5
        cp1y = y0 + (y1 - y0) * 0.5
        cp2x = x1
        cp2y = y1
        cr.curve_to(cp1x, cp1y, cp2x, cp2y, (x1 + x2) * 0.5, (y1 + y2) * 0.5)
    cr.line_to(*points[-1])


def draw_func(_area, cr, width, height):
    import cairo
    cr.set_operator(cairo.OPERATOR_SOURCE)
    cr.set_source_rgba(0, 0, 0, 0)
    cr.paint()

    n = len(bar_values)
    if n == 0:
        return

    # Limit drawing area to height_pct centered vertically
    max_h = height * (_args.height_pct / 100)
    center_y = height / 2

    cr.set_operator(cairo.OPERATOR_OVER)

    # Build point arrays for the smooth curve
    step = width / max(1, n - 1)
    points_top = []
    points_bot = []
    for i, val in enumerate(bar_values):
        x = i * step
        h = val * max_h * 0.5
        if _args.mirror:
            points_top.append((x, center_y - h))
            points_bot.append((x, center_y + h))
        else:
            points_top.append((x, center_y + max_h * 0.5 - h * 2))
            points_bot.append((x, center_y + max_h * 0.5))

    # 3-color sliding gradient: primary → secondary → tertiary → primary
    p = _gradient_phase
    # One full color cycle spans 1.2x the screen width
    span = width * 1.5
    gx0 = -span + p * span
    gx1 = gx0 + span

    gradient = cairo.LinearGradient(gx0, 0, gx1, 0)
    gradient.add_color_stop_rgba(0.00, *FG_PRIMARY, _args.opacity)
    gradient.add_color_stop_rgba(0.33, *FG_SECONDARY, _args.opacity)
    gradient.add_color_stop_rgba(0.66, *FG_TERTIARY, _args.opacity)
    gradient.add_color_stop_rgba(1.00, *FG_PRIMARY, _args.opacity)
    gradient.set_extend(1)  # REPEAT

    lo = min(1.0, _args.opacity * 2)
    line_gradient = cairo.LinearGradient(gx0, 0, gx1, 0)
    line_gradient.add_color_stop_rgba(0.00, *FG_PRIMARY, lo)
    line_gradient.add_color_stop_rgba(0.33, *FG_SECONDARY, lo)
    line_gradient.add_color_stop_rgba(0.66, *FG_TERTIARY, lo)
    line_gradient.add_color_stop_rgba(1.00, *FG_PRIMARY, lo)
    line_gradient.set_extend(1)

    # Top half: curve from center upward, filled down to center
    cr.new_path()
    smooth_curve(cr, points_top)
    cr.line_to(width, center_y)
    cr.line_to(0, center_y)
    cr.close_path()
    cr.set_source(gradient)
    cr.fill()

    cr.new_path()
    smooth_curve(cr, points_top)
    cr.set_source(line_gradient)
    cr.set_line_width(2)
    cr.stroke()

    if _args.mirror:
        # Bottom half: curve from center downward, filled up to center
        cr.new_path()
        smooth_curve(cr, points_bot)
        cr.line_to(width, center_y)
        cr.line_to(0, center_y)
        cr.close_path()
        cr.set_source(gradient)
        cr.fill()

        cr.new_path()
        smooth_curve(cr, points_bot)
        cr.set_source(line_gradient)
        cr.set_line_width(2)
        cr.stroke()


def build_cava_config():
    config_path = os.path.expanduser("~/.config/cava/config_hypr_visualizer")
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    config = f"""[general]
bars = {_args.bars}
framerate = {_args.framerate}
autosens = 1
sensitivity = 150
monstercat = {1 if _args.monstercat else 0}
noise_reduction = {_args.noise_reduction}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
channels = mono
mono_option = average
"""
    with open(config_path, "w") as f:
        f.write(config)
    return config_path


def cava_reader():
    global bar_values
    config_path = build_cava_config()
    proc = subprocess.Popen(
        ["cava", "-p", config_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    try:
        import select
        fd = proc.stdout.fileno()
        os.set_blocking(fd, False)
        buf = b""
        while True:
            select.select([fd], [], [])
            # Drain all available data, keep only the last complete line
            while True:
                try:
                    chunk = os.read(fd, 65536)
                    if not chunk:
                        return
                    buf += chunk
                except BlockingIOError:
                    break
            if b"\n" not in buf:
                continue
            # Take only the last complete line
            rest, _, trailing = buf.rpartition(b"\n")
            buf = trailing
            if b"\n" in rest:
                last_line = rest.rsplit(b"\n", 1)[1]
            else:
                last_line = rest
            vals = last_line.decode().strip().rstrip(";").split(";")
            try:
                bar_values = [min(1.0, int(v) / 1000) for v in vals if v]
            except ValueError:
                continue
            GLib.idle_add(queue_draw)
    except Exception:
        pass
    finally:
        proc.kill()


def queue_draw():
    if drawing_area:
        drawing_area.queue_draw()
    return False


def color_reload_watcher():
    """Watch colors.conf for changes and reload."""
    import time
    last_mtime = 0
    while True:
        try:
            mtime = os.path.getmtime(COLORS_FILE)
            if mtime != last_mtime:
                last_mtime = mtime
                GLib.idle_add(reload_colors)
        except Exception:
            pass
        time.sleep(2)


def on_activate(app):
    global win, drawing_area

    win = Gtk.ApplicationWindow(application=app)

    LayerShell.init_for_window(win)
    LayerShell.set_layer(win, LayerShell.Layer.BACKGROUND)
    LayerShell.set_anchor(win, LayerShell.Edge.TOP, True)
    LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
    LayerShell.set_anchor(win, LayerShell.Edge.LEFT, True)
    LayerShell.set_anchor(win, LayerShell.Edge.RIGHT, True)
    LayerShell.set_exclusive_zone(win, -1)
    LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
    LayerShell.set_namespace(win, "hypr-cava-visualizer")

    drawing_area = Gtk.DrawingArea()
    drawing_area.set_vexpand(True)
    drawing_area.set_hexpand(True)
    drawing_area.set_draw_func(draw_func)
    win.set_child(drawing_area)

    css = Gtk.CssProvider()
    css.load_from_string("window, window.background { background: transparent; }")
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    win.present()

    # Advance gradient phase ~60fps
    def tick_gradient():
        global _gradient_phase
        _gradient_phase = (_gradient_phase + GRADIENT_SPEED / 60) % 1.0
        if drawing_area:
            drawing_area.queue_draw()
        return True
    GLib.timeout_add(16, tick_gradient)

    threading.Thread(target=cava_reader, daemon=True).start()
    threading.Thread(target=color_reload_watcher, daemon=True).start()


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    app = Gtk.Application(application_id="dev.hypr.cava-visualizer")
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()
