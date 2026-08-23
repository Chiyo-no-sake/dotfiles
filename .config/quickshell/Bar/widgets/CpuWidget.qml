import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// CPU usage: rolling sparkline + percent, printed as plain text by the
// waybar-era script. The script sleeps 0.2s to take a /proc/stat
// differential, so it is polled slowly and its verbatim output is shown.
BarWidget {
  id: root
  moduleName: "qs.cpu"

  readonly property string home: Quickshell.env("HOME") || ""
  // Exactly what the script printed minus the trailing newline; internal
  // spacing (the %3d pad between sparkline and percent) is preserved so the
  // label does not reflow between polls.
  property string cpuText: ""

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
    command: [root.home + "/dotfiles/.config/waybar/modules/cpu-sparkline.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = String(text || "").trim()
        if (out.length > 0) root.cpuText = out
      }
    }
  }

  // Stable slot: the script pads the percent to 3 chars already; measure
  // the worst case so the slot follows the live bar font.
  TextMetrics {
    id: cpuMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    text: "▁▂▃▄▅▆ 100%"
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.cpuText
    tooltipText: "CPU usage"
    fixedWidth: root.cpuText !== "" ? Math.ceil(cpuMetrics.advanceWidth) + Style.spaceReal(17) : 0
  }
}
