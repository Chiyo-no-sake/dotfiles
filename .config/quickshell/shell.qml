import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Bar"

// Shell host. Owns: layout config IO, the cross-monitor module-instance
// registry, IPC ownership arbitration, and the shell-level IPC target.
// See ARCHITECTURE.md for the full contract surface.
ShellRoot {
  id: shell

  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell"
  readonly property string layoutPath: configDir + "/layout.json"

  // ---------------------------------------------------------------- layout

  readonly property var defaultLayout: ({
    left: [{ id: "workspaces" }],
    center: [{ id: "clock" }],
    right: [
      { id: "audio" },
      { id: "network" },
      { id: "bluetooth" },
      { id: "monitor" },
      { id: "power" },
      { id: "tray" }
    ]
  })

  property var layout: defaultLayout

  function normalizeLayout(parsed) {
    var out = { left: [], center: [], right: [] }
    if (!parsed || typeof parsed !== "object") return defaultLayout
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var key = sections[s]
      var arr = parsed[key]
      if (!(arr instanceof Array)) continue
      var list = []
      for (var i = 0; i < arr.length; i++) {
        var entry = arr[i]
        if (typeof entry === "string") entry = { id: entry }
        if (entry && typeof entry.id === "string") list.push(entry)
      }
      out[key] = list
    }
    return out
  }

  function applyLayout(raw) {
    var parsed = null
    var text = String(raw || "").trim()
    if (text) {
      try {
        parsed = JSON.parse(text)
      } catch (e) {
        console.warn("layout.json parse failed, using defaults:", e)
      }
    }
    layout = parsed ? normalizeLayout(parsed) : defaultLayout
  }

  function persistLayout(next) {
    layout = normalizeLayout(next)
    layoutFile.setText(JSON.stringify(layout, null, 2) + "\n")
  }

  // Persist per-module inline settings: merges `settings` into the module's
  // layout entry (wherever it lives) and writes the file atomically.
  function updateEntryInline(moduleName, settings) {
    var bareId = String(moduleName || "").replace(/^qs\./, "")
    var copy = JSON.parse(JSON.stringify(layout))
    var sections = ["left", "center", "right"]
    var dirty = false
    for (var s = 0; s < sections.length; s++) {
      var arr = copy[sections[s]] || []
      for (var i = 0; i < arr.length; i++) {
        if (arr[i] && arr[i].id === bareId) {
          var next = { id: bareId }
          for (var k in settings) if (k !== "id") next[k] = settings[k]
          if (JSON.stringify(arr[i]) !== JSON.stringify(next)) {
            arr[i] = next
            dirty = true
          }
        }
      }
    }
    if (dirty) persistLayout(copy)
    return dirty
  }

  property FileView layoutFile: FileView {
    path: shell.layoutPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: shell.applyLayout(text())
    onLoadFailed: function(error) {
      // No user layout yet — defaults keep the bar usable.
      shell.applyLayout("")
    }
    onFileChanged: reload()
  }

  // ------------------------------------------------- module instance registry
  //
  // moduleName -> array of live instances across every monitor's bar.
  // Reassigned wholesale so length bindings re-evaluate.

  property var instances: ({})

  function registerInstance(moduleName, item) {
    if (!moduleName || !item) return
    var key = String(moduleName)
    var list = instances[key] || []
    if (list.indexOf(item) !== -1) return
    var next =({})
    for (var k in instances) next[k] = instances[k]
    next[key] = list.concat([item])
    instances = next
  }

  function unregisterInstance(moduleName, item) {
    var key = String(moduleName)
    var list = instances[key]
    if (!list || list.indexOf(item) === -1) return
    var filtered = []
    for (var i = 0; i < list.length; i++)
      if (list[i] !== item) filtered.push(list[i])
    var next = ({})
    for (var k in instances) next[k] = instances[k]
    if (filtered.length > 0) next[key] = filtered
    else delete next[key]
    instances = next
    if (ipcOwners[key] === item) {
      var owners = ({})
      for (var o in ipcOwners) owners[o] = ipcOwners[o]
      delete owners[key]
      ipcOwners = owners
    }
  }

  function instancesOf(moduleName) {
    var list = instances[String(moduleName)]
    var out = []
    if (list) for (var i = 0; i < list.length; i++) {
      var inst = list[i]
      if (!inst) continue
      // Belt and braces against destroyed-but-referenced wrappers that
      // escaped unregisterInstance: dead items fail the property probe.
      try {
        if (inst.moduleName === undefined && !("opened" in inst) && !("bar" in inst)) continue
      } catch (e) {
        continue
      }
      out.push(inst)
    }
    return out
  }

  // -------------------------------------------------------- IPC arbitration
  //
  // Exactly one instance per moduleName may own its IpcHandler; the rest run
  // with manageIpc false and receive relays through broadcast().

  property var ipcOwners: ({})

  function claimPanelIpc(moduleName, item) {
    var key = String(moduleName)
    if (ipcOwners[key]) return false
    var owners = ({})
    for (var o in ipcOwners) owners[o] = ipcOwners[o]
    owners[key] = item
    ipcOwners = owners
    return true
  }

  // ------------------------------------------------------------ shell facade

  function summon(id, payloadJson) {
    // No overlay plugins (OSD etc.) in v1 — panels open via their bar
    // instance or IPC toggle. Returning false is the documented "absent".
    return false
  }

  function firstPartyServiceFor(id) {
    return null
  }

  // ------------------------------------------------------------------- bar

  Registry {
    id: registry
  }

  Bar {
    shell: shell
    registry: registry
  }

  // ------------------------------------------------------------------ IPC

  IpcHandler {
    target: "shell"

    function ping(): string {
      return "ok"
    }

    // Debug/introspection: live property snapshot of a module instance —
    // e.g. `state audio` returns the audio panel's default sink/source.
    function state(id: string): string {
      var list = shell.instancesOf(shell.qualifyName(id))
      if (list.length === 0) return "unknown"
      var inst = list[0]
      var out = { moduleName: inst.moduleName || "", opened: inst.opened === true }
      var probe = ["sink", "source", "volumeSinkName", "focusedMonitor", "monitorScale", "brightnessPercent", "tunedProfile", "tunedAvailable", "amphetamineOn", "amphetamineInf", "amphetamineMinutesLeft", "themeMode"]
      for (var i = 0; i < probe.length; i++) {
        var key = probe[i]
        try {
          if (inst[key] !== undefined && inst[key] !== null) {
            var v = inst[key]
            out[key] = v && v.name !== undefined ? String(v.name) : String(v)
          }
        } catch (e) {
          // property access on a destroyed instance — skip
        }
      }
      return JSON.stringify(out)
    }

    function reload(): string {
      Quickshell.reload()
      return "ok"
    }

    function listPanels(): string {
      var out = []
      for (var name in shell.instances) {
        out.push({
          moduleName: name,
          instances: shell.instances[name].length
        })
      }
      return JSON.stringify(out)
    }

    // NOTE: named openPanel/closePanel rather than show/hide because `show`
    // collides with a reserved word in quickshell's CLI parser.
    function openPanel(id: string): string {
      return shell.setPanelsOpen(id, true)
    }

    function closePanel(id: string): string {
      return shell.setPanelsOpen(id, false)
    }

    function toggle(id: string): string {
      var list = shell.instancesOf(shell.qualifyName(id))
      if (list.length === 0) return "unknown"
      return shell.setPanelsOpen(id, !list[0].opened)
    }
  }

  function setPanelsOpen(id, open) {
    var list = instancesOf(qualifyName(id))
    if (list.length === 0) return "unknown"
    for (var i = 0; i < list.length; i++) {
      if (!list[i] || typeof list[i].open !== "function") continue
      if (open) list[i].open()
      else list[i].close()
    }
    return "ok"
  }

  function qualifyName(id) {
    var name = String(id)
    return name.indexOf("qs.") === 0 ? name : "qs." + name
  }

  Component.onCompleted: {
    applyLayout("")
    if (layoutFile.loaded) applyLayout(layoutFile.text())
  }
}
