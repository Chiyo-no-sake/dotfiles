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
_parser.add_argument("--opacity", type=float, default=0.33, help="Bar opacity (default: 0.33)")
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
    """Return framerate scaled to power profile, aligned to monitor refresh."""
    profile = detect_power_profile()
    if profile == "power-saver":
        return 33  # 165/5
    elif profile == "balanced":
        return 55  # 165/3
    # performance: half the monitor refresh avoids compositor judder
    return min(framerate, 82)  # 165/2 ≈ 82

if _args.framerate <= 0:
    _args.framerate = apply_power_scaling(detect_refresh_rate())

# ── State ──────────────────────────────────────────────────
bar_values = [0.0] * _args.bars
win = None
drawing_area = None
_gradient_phase = 0.0  # 0..1, shifts the gradient horizontally
_last_draw_time = 0.0  # monotonic timestamp of last draw
_win_opacity = 0.0     # current window opacity (for fade in/out)
GRADIENT_SPEED = 0.15  # full cycles per second
SILENCE_THRESHOLD = 0.02  # below this peak → silence (2% of max)
FADE_IN_SPEED = 3.0    # opacity units/sec (0→1 in ~0.33s)
FADE_OUT_SPEED = 1.5   # opacity units/sec (1→0 in ~0.67s)


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


def rgb_to_hsl(r, g, b):
    cmax, cmin = max(r, g, b), min(r, g, b)
    delta = cmax - cmin
    l = (cmax + cmin) / 2
    if delta == 0:
        return 0, 0, l
    s = delta / (1 - abs(2 * l - 1))
    if cmax == r:
        h = ((g - b) / delta) % 6
    elif cmax == g:
        h = (b - r) / delta + 2
    else:
        h = (r - g) / delta + 4
    return h / 6, min(s, 1.0), l


def hsl_to_rgb(h, s, l):
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs((h * 6) % 2 - 1))
    m = l - c / 2
    h6 = int(h * 6) % 6
    r, g, b = [(c,x,0),(x,c,0),(0,c,x),(0,x,c),(x,0,c),(c,0,x)][h6]
    return (r + m, g + m, b + m)


def boost_saturation(rgb, amount=0.35):
    h, s, l = rgb_to_hsl(*rgb)
    s = min(1.0, s + amount)
    return hsl_to_rgb(h, s, l)


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
    import cairo, time
    global _gradient_phase, _last_draw_time

    now = time.monotonic()
    dt = now - _last_draw_time if _last_draw_time > 0 else 0
    _last_draw_time = now
    _gradient_phase = (_gradient_phase + GRADIENT_SPEED * dt) % 1.0

    # Fade window based on audio level
    global _win_opacity
    peak = max(bar_values) if bar_values else 0.0
    if peak > SILENCE_THRESHOLD:
        _win_opacity = min(1.0, _win_opacity + FADE_IN_SPEED * dt)
    else:
        _win_opacity = max(0.0, _win_opacity - FADE_OUT_SPEED * dt)

    if _win_opacity < 0.005:
        # Fully silent — clear and skip all drawing
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        return

    n = len(bar_values)
    if n == 0:
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        return

    # Limit drawing area to height_pct centered vertically
    max_h = height * (_args.height_pct / 100)
    center_y = height / 2

    # Clip + clear only the band where bars can appear (not the full 3440x1440)
    band_top = center_y - max_h * 0.5 - 4
    band_bot = center_y + max_h * 0.5 + 4
    cr.save()
    cr.rectangle(0, band_top, width, band_bot - band_top)
    cr.clip()

    cr.set_operator(cairo.OPERATOR_SOURCE)
    cr.set_source_rgba(0, 0, 0, 0)
    cr.paint()

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
    span = width * 1.5
    gx0 = -span + _gradient_phase * span
    gx1 = gx0 + span

    # Apply fade opacity to all alpha values
    oa = _args.opacity * _win_opacity

    gradient = cairo.LinearGradient(gx0, 0, gx1, 0)
    gradient.add_color_stop_rgba(0.00, *FG_PRIMARY, oa)
    gradient.add_color_stop_rgba(0.33, *FG_SECONDARY, oa)
    gradient.add_color_stop_rgba(0.66, *FG_TERTIARY, oa)
    gradient.add_color_stop_rgba(1.00, *FG_PRIMARY, oa)
    gradient.set_extend(1)  # REPEAT

    lo = min(1.0, _args.opacity * 2) * _win_opacity
    line_gradient = cairo.LinearGradient(gx0, 0, gx1, 0)
    line_gradient.add_color_stop_rgba(0.00, *FG_PRIMARY, lo)
    line_gradient.add_color_stop_rgba(0.33, *FG_SECONDARY, lo)
    line_gradient.add_color_stop_rgba(0.66, *FG_TERTIARY, lo)
    line_gradient.add_color_stop_rgba(1.00, *FG_PRIMARY, lo)
    line_gradient.set_extend(1)

    # ── Boost: 2D gradient with saturation peak at center_y ──
    # Instead of a separate clip+mask pass, use a vertical gradient that blends
    # the boosted colors near center and the normal colors at the edges.
    boost_h = max_h * 0.25
    bp = boost_saturation(FG_PRIMARY, 0.25)
    bs = boost_saturation(FG_SECONDARY, 0.25)
    bt = boost_saturation(FG_TERTIARY, 0.25)
    def make_gradient(y_from_center):
        """Return gradient with opacity fading based on distance from center."""
        dist = abs(y_from_center) / max(1, boost_h)
        if dist >= 1.0:
            return gradient  # outside boost zone, use normal gradient
        # Blend: closer to center → more saturated, brighter
        t = 1.0 - dist
        o = (_args.opacity + (_args.opacity * 0.5) * t) * _win_opacity
        g = cairo.LinearGradient(gx0, 0, gx1, 0)
        g.add_color_stop_rgba(0.00, *interpolate_color(FG_PRIMARY, bp, t), o)
        g.add_color_stop_rgba(0.33, *interpolate_color(FG_SECONDARY, bs, t), o)
        g.add_color_stop_rgba(0.66, *interpolate_color(FG_TERTIARY, bt, t), o)
        g.add_color_stop_rgba(1.00, *interpolate_color(FG_PRIMARY, bp, t), o)
        g.set_extend(1)
        return g

    # Top half: build curve, stroke it, then close + fill
    cr.new_path()
    smooth_curve(cr, points_top)
    stroke_top = cr.copy_path()
    cr.line_to(width, center_y)
    cr.line_to(0, center_y)
    cr.close_path()
    cr.set_source(make_gradient(-max_h * 0.15))
    cr.fill()

    cr.new_path()
    cr.append_path(stroke_top)
    cr.set_source(line_gradient)
    cr.set_line_width(2)
    cr.stroke()

    if _args.mirror:
        cr.new_path()
        smooth_curve(cr, points_bot)
        stroke_bot = cr.copy_path()
        cr.line_to(width, center_y)
        cr.line_to(0, center_y)
        cr.close_path()
        cr.set_source(make_gradient(max_h * 0.15))
        cr.fill()

        cr.new_path()
        cr.append_path(stroke_bot)
        cr.set_source(line_gradient)
        cr.set_line_width(2)
        cr.stroke()

    cr.restore()  # release the band clip


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
    global bar_values, _cava_dirty
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
            _cava_dirty = True
    except Exception:
        pass
    finally:
        proc.kill()


_cava_dirty = False


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

    # Single unified frame tick — redraws on new data or during fade transitions
    frame_interval = max(8, 1000 // _args.framerate)
    def frame_tick():
        global _cava_dirty
        fading = 0.005 < _win_opacity < 0.995
        if (_cava_dirty or fading) and drawing_area:
            _cava_dirty = False
            drawing_area.queue_draw()
        return True
    GLib.timeout_add(frame_interval, frame_tick)

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
