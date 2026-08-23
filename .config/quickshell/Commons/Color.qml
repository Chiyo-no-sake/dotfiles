pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Color surfaces for the shell, driven by matugen Material You colors.
// Replaces omarchy's theme/toml machinery: a matugen template renders
// ~/.config/quickshell/colors.json from the wallpaper palette and this
// singleton maps it onto the role API the vendored Ui components and
// panels expect (foreground/background/accent/urgent/muted + bar/popups/
// tooltip roles). File watching means a wallpaper change re-themes the
// shell live.
QtObject {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
  readonly property string colorsPath: configHome + "/quickshell/colors.json"

  // Fallback palette used until matugen generates colors.json for the
  // first time (matches the shipped dark defaults).
  property color foreground: "#e3e1e9"
  property color background: "#121318"
  property color accent: "#bac3ff"
  // Second accent stop: hyprland's active window border is a primary→
  // tertiary 45° gradient, so interactive markers that want to echo it
  // need both ends.
  property color accentB: "#e5bad8"
  property color urgent: "#ffb4ab"
  property color muted: "#c6c5d0"

  // Raw parsed palette from colors.json. Reassigned wholesale so
  // dependent bindings re-evaluate on theme change.
  property var palette: ({})

  // Compat: vendored Commons/Border.qml and Ui components read surface
  // tokens through Color.shellValues / pick / pickAlpha. We theme through
  // the role API below instead, so this map stays empty and every caller
  // falls back to the explicit fallback colors passed alongside.
  readonly property var shellValues: ({})

  function pick(key, fallback) {
    var v = shellValues[key]
    return (typeof v === "string" && v.length > 0) ? v : fallback
  }

  function pickAlpha(key, fallback) {
    var v = shellValues[key]
    if (typeof v !== "string" || v.length === 0) return fallback
    var n = Number(v)
    return isFinite(n) ? Util.clampAlpha(n) : fallback
  }

  function pal(name, fallback) {
    var v = palette[name]
    return (typeof v === "string" && v.length > 0) ? v : fallback
  }

  function alphaOf(base, a) {
    return Qt.rgba(base.r, base.g, base.b, a)
  }

  readonly property QtObject bar: QtObject {
    property color background: root.alphaOf(root.background, 0.92)
    property color text: root.foreground
    property color active: root.accent
  }

  readonly property QtObject popups: QtObject {
    property color background: root.pal("surface_bright", "#39393f")
    property color text: root.pal("on_surface", "#e3e1e9")
    property color border: root.alphaOf(root.pal("outline", "#8a8a94"), 0.45)
  }

  readonly property QtObject tooltip: QtObject {
    property color background: root.pal("surface_bright", "#39393f")
    property color text: root.pal("on_surface", "#e3e1e9")
    property color border: root.alphaOf(root.pal("outline", "#8a8a94"), 0.45)
  }

  property string lastAppliedRaw: "\u0000"

  function applyPalette(raw) {
    var text = String(raw || "")
    if (text === lastAppliedRaw) return
    lastAppliedRaw = text
    var parsed = {}
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      console.warn("quickshell colors.json parse failed:", e)
      return
    }
    palette = parsed

    // Foundational palette. Roles follow the Material You mapping matugen
    // generates from the wallpaper.
    var fg = pal("on_background", "#e3e1e9")
    var bg = pal("background", "#121318")
    var ac = pal("primary", "#bac3ff")
    var ur = pal("error", "#ffb4ab")
    var mu = pal("outline", "#c6c5d0")

    // Validate hex before assigning — Qt throws on bad color strings.
    function safe(v, fallback) {
      return String(v).match(/^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/) ? v : fallback
    }

    foreground = safe(fg, foreground)
    background = safe(bg, background)
    accent = safe(ac, accent)
    accentB = safe(pal("tertiary", "#e5bad8"), accentB)
    urgent = safe(ur, urgent)
    muted = safe(mu, muted)
  }

  property FileView colorsFile: FileView {
    path: root.colorsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyPalette(text())
    onLoadFailed: function(error) {
      // Missing file just means matugen has not run yet; keep defaults.
    }
    onFileChanged: reload()
  }

  // Robustness net: matugen (and atomic writers in general) can replace
  // colors.json via rename, which inotify-based watches can miss. Poll by
  // reloading periodically — applyPalette short-circuits on identical
  // content, so the steady-state cost is reading a tiny file.
  property Timer colorsPollTimer: Timer {
    interval: 1500
    running: true
    repeat: true
    onTriggered: root.colorsFile.reload()
  }

  Component.onCompleted: {
    if (colorsFile.loaded) root.applyPalette(colorsFile.text())
  }
}
