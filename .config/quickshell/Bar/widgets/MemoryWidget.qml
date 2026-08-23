import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Memory usage straight from /proc/meminfo: label shows the used percent,
// tooltip spells out used/total in GiB. No helper script involved.
BarWidget {
  id: root
  moduleName: "qs.memory"

  property int memTotalKiB: 0
  property int memAvailableKiB: 0

  readonly property bool haveStats: memTotalKiB > 0 && memAvailableKiB >= 0
  readonly property int usedPercent: haveStats
    ? Math.round((1 - memAvailableKiB / memTotalKiB) * 100) : 0
  readonly property string usedGiB: haveStats
    ? ((memTotalKiB - memAvailableKiB) / 1024 / 1024).toFixed(1) : "0.0"
  readonly property string totalGiB: haveStats
    ? (memTotalKiB / 1024 / 1024).toFixed(1) : "0.0"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function applyMeminfo(raw) {
    var text = String(raw || "")
    var total = text.match(/MemTotal:\s+(\d+)/)
    var available = text.match(/MemAvailable:\s+(\d+)/)
    // Missing keys keep the previous state rather than blanking the widget.
    if (!total || !available) return
    var totalKiB = parseInt(total[1], 10)
    var availableKiB = parseInt(available[1], 10)
    if (!(totalKiB > 0) || !(availableKiB >= 0)) return
    root.memTotalKiB = totalKiB
    root.memAvailableKiB = availableKiB
  }

  Component.onCompleted: proc.running = true

  Timer {
    id: pollTimer
    interval: 5000
    running: true
    repeat: true
    onTriggered: proc.running = true
  }

  Process {
    id: proc
    command: ["cat", "/proc/meminfo"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyMeminfo(text)
    }
  }

  // Stable slot for the 1-3 digit percent range, measured at the live bar
  // font (worst case "100%").
  TextMetrics {
    id: memMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    text: "󰍛 100%"
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.haveStats ? "󰍛 " + root.usedPercent + "%" : ""
    tooltipText: root.haveStats
      ? root.usedGiB + "G / " + root.totalGiB + "G (" + root.usedPercent + "%)" : ""
    fixedWidth: root.haveStats ? Math.ceil(memMetrics.advanceWidth) + Style.spaceReal(17) : 0
  }
}
