import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Per-workspace layout switcher (dwindle ↔ scrolling), driven by the
// user's waybar-era layout-toggle.sh — same engine as the Super+G bind,
// and the same state dir, so the two never disagree.
BarWidget {
  id: root
  moduleName: "qs.wsmode"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string engine: home + "/.config/waybar/modules/layout-toggle.sh"
  property bool scrolling: false
  property string tooltip: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: proc.running = true

  Timer {
    id: pollTimer
    interval: 2000
    running: true
    repeat: true
    onTriggered: proc.running = true
  }

  Process {
    id: proc
    command: ["bash", "-c", "'" + root.engine + "' 2>/dev/null || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "{}"))
          root.scrolling = parsed.class === "scrolling"
          root.tooltip = parsed.tooltip || ""
        } catch (e) {
          // keep previous state
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.scrolling ? "󱎞" : "󰕰"
    tooltipText: root.tooltip !== ""
      ? root.tooltip + " — click to toggle"
      : (root.scrolling ? "Scrolling layout — click for dwindle" : "Dwindle layout — click for scrolling")
    active: root.scrolling
    onPressed: function(button) {
      toggleProc.running = true
    }
  }

  Process {
    id: toggleProc
    command: ["bash", "-c", "'" + root.engine + "' toggle >/dev/null 2>&1; '" + root.engine + "' 2>/dev/null || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "{}"))
          root.scrolling = parsed.class === "scrolling"
          root.tooltip = parsed.tooltip || ""
        } catch (e) {
          root.proc.running = true
        }
      }
    }
  }
}
