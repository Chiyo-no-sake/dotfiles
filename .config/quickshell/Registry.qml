import QtQuick

// Static module registry — THE extension point of the bar.
//
// Adding a module:
//   1. create Panels/<name>/NamePanel.qml or Bar/widgets/Name.qml
//      implementing the module contract (see ARCHITECTURE.md)
//   2. add an entry here
//   3. add {"id": "<name>"} to layout.json
//
// ids are bare ("audio"); moduleNames are namespaced ("qs.audio").
QtObject {
  id: registry

  readonly property var modules: ({
    "workspaces": { url: Qt.resolvedUrl("Bar/widgets/Workspaces.qml"), section: "left" },
    "clock": { url: Qt.resolvedUrl("Panels/clock/ClockWidget.qml"), section: "center" },
    "wsmode": { url: Qt.resolvedUrl("Bar/widgets/WorkspaceModeWidget.qml"), section: "center" },
    "cpu": { url: Qt.resolvedUrl("Bar/widgets/CpuWidget.qml"), section: "right" },
    "memory": { url: Qt.resolvedUrl("Bar/widgets/MemoryWidget.qml"), section: "right" },
    "netspeed": { url: Qt.resolvedUrl("Bar/widgets/NetworkSpeedWidget.qml"), section: "right" },
    "audio": { url: Qt.resolvedUrl("Panels/audio/AudioPanel.qml"), section: "right" },
    "network": { url: Qt.resolvedUrl("Panels/network/NetworkPanel.qml"), section: "right" },
    "bluetooth": { url: Qt.resolvedUrl("Panels/bluetooth/BluetoothPanel.qml"), section: "right" },
    "monitor": { url: Qt.resolvedUrl("Panels/monitor/MonitorPanel.qml"), section: "right" },
    "power": { url: Qt.resolvedUrl("Panels/power/PowerPanel.qml"), section: "right" },
    "clipboard": { url: Qt.resolvedUrl("Panels/clipboard/ClipboardPanel.qml"), section: "right" },
    "tray": { url: Qt.resolvedUrl("Bar/widgets/Tray.qml"), section: "right" }
  })

  function has(id) {
    return Object.prototype.hasOwnProperty.call(modules, String(id))
  }

  function urlFor(id) {
    var entry = modules[String(id)]
    return entry ? entry.url : ""
  }

  function moduleNameFor(id) {
    return has(id) ? "qs." + String(id) : ""
  }

  function defaultSectionFor(id) {
    var entry = modules[String(id)]
    return entry && entry.section ? entry.section : "right"
  }

  function ids() {
    return Object.keys(modules)
  }
}
