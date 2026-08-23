import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Network throughput: verbatim "down up" plain text from the waybar-era
// script. The script sleeps 1s between /sys/class/net counters, so polling
// is the only driver. Fixed slot width keeps the bar from jittering as the
// digit count changes between polls.
BarWidget {
  id: root
  moduleName: "qs.netspeed"

  readonly property string home: Quickshell.env("HOME") || ""
  property string netText: ""

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
    command: [root.home + "/dotfiles/.config/waybar/modules/network-speed.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = String(text || "").trim()
        if (out.length > 0) root.netText = out
      }
    }
  }

  // Measured worst-case slot: the script prints e.g. "󰁆 1186M 󰁞 999K"
  // (nerd-font arrows + %4s values). Measure at the live bar font so the
  // fixed slot follows text-size changes instead of clipping like the old
  // literal Style.space(16) (16 *pixels* — the waybar "min-length: 16"
  // meant 16 *characters*).
  TextMetrics {
    id: speedMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    text: "󰁆 8888M 󰁞 8888M"
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.netText
    tooltipText: "Network throughput"
    fixedWidth: Math.ceil(speedMetrics.advanceWidth) + Style.spaceReal(17)
  }
}
