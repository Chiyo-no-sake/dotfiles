import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Bar host. One root for the whole shell; one BarSurface per monitor.
// The root owns every piece of state the Ui kit reads through the Bar API
// (tooltip, popout coordination, click-target registry); surfaces own the
// windows and section layout. Full contract in ARCHITECTURE.md.
Item {
  id: root

  required property var shell
  required property var registry

  // ------------------------------------------------------------ bar chrome

  readonly property bool vertical: false
  readonly property string position: "top"
  readonly property int barSize: Style.bar.sizeHorizontal
  readonly property string fontFamily: Style.font.family
  property color foreground: Color.bar.text
  property color barForeground: foreground
  property color background: Color.bar.background
  property color urgent: Color.bar.active
  property bool foregroundAnimationEnabled: true

  Behavior on barForeground {
    enabled: root.foregroundAnimationEnabled
    ColorAnimation {
      duration: 420
      easing.type: Easing.InOutCubic
    }
  }

  Behavior on background {
    ColorAnimation {
      duration: 420
      easing.type: Easing.InOutCubic
    }
  }

  function run(command) {
    Quickshell.execDetached(["sh", "-c", String(command)])
  }

  // ------------------------------------------------- cross-surface registry

  function moduleWidgets(moduleName) {
    return shell.instancesOf(moduleName)
  }

  // Tab cycles panels in layout order (center, then right).
  readonly property var panelOrder: {
    var layout = shell.layout || ({})
    var ids = (layout.center || []).concat(layout.right || [])
    var names = []
    for (var i = 0; i < ids.length; i++) {
      var name = root.registry.moduleNameFor(ids[i].id)
      if (name) names.push(name)
    }
    return names
  }

  function switchPanelFrom(item, direction) {
    var name = item && item.moduleName ? String(item.moduleName) : ""
    var order = panelOrder
    var index = order.indexOf(name)
    if (index === -1) return false
    var count = order.length
    for (var step = 1; step <= count; step++) {
      var next = ((direction >= 0 ? index + step : index - step) % count + count) % count
      var candidates = moduleWidgets(order[next])
      for (var c = 0; c < candidates.length; c++) {
        if (candidates[c] && typeof candidates[c].open === "function") {
          if (typeof item.closeForPopoutSwitch === "function") item.closeForPopoutSwitch()
          else if (typeof item.close === "function") item.close()
          candidates[c].open()
          return true
        }
      }
    }
    return false
  }

  // --------------------------------------------------- popout coordination

  property var activePopout: null

  // One open panel per bar: when a panel registers as the active popout,
  // every OTHER panel instance closes. The KeyboardPanel of the newly
  // opened one requests the slot in onOpenChanged; siblings that watch
  // this handler get shut here. Closes go through closeForPopoutSwitch
  // when available so the outgoing card plays its hand-off fade instead
  // of a hard cut.
  onActivePopoutChanged: {
    if (activePopout === null) return
    for (var name in shell.instances) {
      var list = shell.instances[name]
      for (var i = 0; i < list.length; i++) {
        var inst = list[i]
        if (!inst || inst === activePopout) continue
        if (inst.opened !== true) continue
        if (typeof inst.closeForPopoutSwitch === "function") inst.closeForPopoutSwitch()
        else if (typeof inst.close === "function") inst.close()
      }
    }
  }

  function requestPopout(key) {
    activePopout = key
  }

  function releasePopout(key) {
    if (activePopout === key) activePopout = null
  }

  // ------------------------------------------------------- click forwarding
  //
  // Items with triggerPress(button) register here so KeyboardPanel's
  // fullscreen overlay can route clicks back to bar widgets. Entries are
  // window-agnostic; KeyboardPanel filters by anchor window.

  property var clickTargets: []

  function registerClickTarget(item) {
    if (!item) return
    var list = clickTargets
    for (var i = 0; i < list.length; i++)
      if (list[i] === item) return
    clickTargets = list.concat([item])
  }

  function unregisterClickTarget(item) {
    var list = clickTargets
    var next = []
    for (var i = 0; i < list.length; i++)
      if (list[i] !== item) next.push(list[i])
    if (next.length !== list.length) clickTargets = next
  }

  function targetBelongsToWindow(target, window) {
    if (!target || !window || !window.contentItem) return false
    var item = target
    while (item) {
      if (item === window.contentItem) return true
      item = item.parent
    }
    return false
  }

  // --------------------------------------------------------------- tooltip

  property var tooltipTarget: null
  property string tooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0
  property var pendingTooltipTarget: null
  property string pendingTooltipText: ""

  function targetTooltipHovered(target) {
    if (!target) return false
    var mapped = target.mapToItem(null, target.width / 2, target.height / 2)
    var pos = Quickshell.cursorPosition
    if (!pos) return false
    var w = Math.max(target.width, 1)
    var h = Math.max(target.height, 1)
    return pos.x >= mapped.x - w && pos.x <= mapped.x + w && pos.y >= mapped.y - h && pos.y <= mapped.y + h
  }

  function clearTooltip() {
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
    pendingTooltipTarget = null
    pendingTooltipText = ""
  }

  function showTooltip(target, text) {
    clearTooltip()
    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }
    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text
    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return
    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // ------------------------------------------------------------ per screen

  Variants {
    model: Quickshell.screens

    BarSurface {
      required property var modelData
      screen: modelData
    }
  }

  // Shadow strip under the bar: a separate layer surface anchored just
  // below the bar, non-exclusive (ExclusionMode.Ignore) so tiled windows
  // keep their geometry and slide UNDER the shadow — the shadow is cast
  // on whatever is beneath, like real elevation. Empty input mask makes
  // the whole strip click-through.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData

      screen: modelData
      visible: true
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "qs-bar-shadow"
      WlrLayershell.layer: WlrLayer.Top

      anchors {
        top: true
        left: true
        right: true
      }
      margins.top: root.barSize
      implicitHeight: Math.round(Style.spaceReal(10))

      // Empty region = no input area: clicks pass through to windows.
      mask: Region {}

      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0; color: Util.alpha("#000000", 0.26) }
          GradientStop { position: 0.55; color: Util.alpha("#000000", 0.10) }
          GradientStop { position: 1; color: "transparent" }
        }
      }
    }
  }

  // One layout entry → one ModuleSlot. Owns contract injection, instance
  // registration, IPC arbitration, and the panel underline marker.
  component ModuleSlot: Loader {
    id: widgetLoader

    required property var modelData
    // modelData is null while the center-anchor placeholder binds before
    // the layout settles — guard every deref.
    property string moduleName: modelData ? root.registry.moduleNameFor(modelData.id) : ""
    property var registeredItem: null

    source: modelData ? root.registry.urlFor(modelData.id) : ""

    // Deterministic slot sizing: modules expose implicitWidth/implicitHeight
    // (their actual width is often 0 until laid out), so the slot binds both
    // explicitly instead of relying on Loader's implicit-size propagation.
    width: item ? item.implicitWidth : 0
    height: item ? item.implicitHeight : 0

          // Section underline on EVERY slot: a marker strip at the bar's
          // bottom edge in the hyprland active-border accent (primary at
          // rest; the full primary→tertiary gradient while the widget's
          // panel is open — same pair the window borders use). Spans the
          // module's width with a small inset; a module may expose
          // `underlineWidth` (tray: tracks its hover drawer) to paint a
          // narrower marker, right-aligned so it grows leftward with it.
          Rectangle {
            id: panelUnderline
            readonly property bool panelOpen: widgetLoader.item !== null
              && widgetLoader.item.opened === true
            readonly property bool customExtent: widgetLoader.item !== null
              && widgetLoader.item.underlineWidth !== undefined
            readonly property real markerWidth: customExtent
              ? Math.min(widgetLoader.item.underlineWidth, parent.width - Style.spaceReal(3) * 2)
              : parent.width - Style.spaceReal(3) * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(1, Math.round(Style.spaceReal(1)) - 1)
            anchors.right: parent.right
            anchors.rightMargin: Style.spaceReal(3)
            width: Math.max(0, markerWidth)
            height: Math.max(2, Math.round(Style.spaceReal(2)))
            radius: height / 2
            color: Util.alpha(Color.accent, 0.5)
            gradient: panelOpen ? underlineGradient : null

            Behavior on color { ColorAnimation { duration: 160 } }
          }

          Gradient {
            id: underlineGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Color.accent }
            GradientStop { position: 1; color: Color.accentB }
          }

    function injectModuleContract() {
      if (!item) return
      // The Bar API lives on the root Item — widgets get that, never
      // the per-screen window. Popup anchoring goes through the
      // anchor item's own QsWindow, so nothing needs bar-as-window.
      if ("bar" in item) item.bar = root
      if ("moduleName" in item && moduleName) item.moduleName = moduleName
      if ("settings" in item) {
        var settings = ({})
        for (var key in modelData)
          if (key !== "id") settings[key] = modelData[key]
        item.settings = settings
      }
      if ("manageIpc" in item && moduleName)
        item.manageIpc = root.shell.claimPanelIpc(moduleName, item)
    }

    onItemChanged: {
      if (registeredItem) {
        root.shell.unregisterInstance(moduleName, registeredItem)
        registeredItem = null
      }
      if (!item) return
      injectModuleContract()
      root.shell.registerInstance(moduleName, item)
      registeredItem = item
    }

    // Repeater model churn (any layout rewrite) destroys delegates
    // without firing onItemChanged(null) first — unregister here or
    // dead instances accumulate in the shell registry, holding IPC
    // claims and answering state probes with destroyed objects.
    Component.onDestruction: {
      if (registeredItem) {
        root.shell.unregisterInstance(moduleName, registeredItem)
        registeredItem = null
      }
    }

    // A layout.json re-persist replaces the model array; Repeater
    // rebuilds delegates in that case, but re-inject anyway when only
    // the entry payload is swapped so settings never go stale.
    onModelDataChanged: injectModuleContract()

    onStatusChanged: if (status === Loader.Error)
      console.warn("module " + (modelData ? modelData.id : "?") + " failed to load: " + errorString())
  }

  component SectionRow: Row {
    id: sectionRow

    property string section: ""
    // Inactive rows instantiate nothing: the center fallback row must not
    // create duplicate module instances alongside the anchor layout.
    property bool active: true
    spacing: Style.spaceReal(6)

    Repeater {
      model: {
        if (!sectionRow.active) return []
        var layout = root.shell ? root.shell.layout : null
        return layout && layout[sectionRow.section] ? layout[sectionRow.section] : []
      }

      delegate: ModuleSlot {}
    }
  }

  component BarSurface: PanelWindow {
    id: barWindow

    visible: true
    anchors {
      top: true
      left: true
      right: true
    }
    implicitHeight: root.barSize
    color: root.background
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top

    Item {
      anchors.fill: parent

      SectionRow {
        id: leftSection
        section: "left"
        anchors.left: parent.left
        anchors.leftMargin: Style.spaceReal(2)
        anchors.verticalCenter: parent.verticalCenter
      }

      // Center section. When an entry carries `"anchor": true`, that widget
      // is pinned to the exact screen center and the rest flank it — the
      // clock stays dead-center even as the flanking widgets change width.
      // Without an anchor the section centers as a group (old behavior).
      Item {
        id: centerHost

        anchors.fill: parent

        readonly property var centerEntries: {
          var layout = root.shell ? root.shell.layout : null
          return layout && layout.center ? layout.center : []
        }
        readonly property int anchorIndex: {
          var entries = centerEntries
          for (var i = 0; i < entries.length; i++)
            if (entries[i] && entries[i].anchor === true) return i
          return -1
        }

        SectionRow {
          section: "center"
          active: centerHost.anchorIndex === -1
          visible: centerHost.anchorIndex === -1
          anchors.centerIn: parent
        }

        ModuleSlot {
          id: anchorSlot
          visible: centerHost.anchorIndex !== -1
          anchors.centerIn: parent
          modelData: centerHost.anchorIndex !== -1 ? centerHost.centerEntries[centerHost.anchorIndex] : null
        }

        Row {
          visible: centerHost.anchorIndex > 0
          spacing: Style.spaceReal(6)
          anchors.right: anchorSlot.left
          anchors.rightMargin: Style.spaceReal(1)
          anchors.verticalCenter: parent.verticalCenter

          Repeater {
            model: centerHost.anchorIndex > 0 ? centerHost.centerEntries.slice(0, centerHost.anchorIndex) : []
            delegate: ModuleSlot {}
          }
        }

        Row {
          visible: centerHost.anchorIndex !== -1 && centerHost.anchorIndex < centerHost.centerEntries.length - 1
          spacing: Style.spaceReal(6)
          anchors.left: anchorSlot.right
          anchors.leftMargin: Style.spaceReal(1)
          anchors.verticalCenter: parent.verticalCenter

          Repeater {
            model: centerHost.anchorIndex !== -1 && centerHost.anchorIndex < centerHost.centerEntries.length - 1
              ? centerHost.centerEntries.slice(centerHost.anchorIndex + 1)
              : []
            delegate: ModuleSlot {}
          }
        }
      }

      SectionRow {
        id: rightSection
        section: "right"
        anchors.right: parent.right
        anchors.rightMargin: Style.spaceReal(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }



    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!target || !root.targetBelongsToWindow(target, barWindow)) return
          var popupWidth = tooltipWindow.implicitWidth
          var popupHeight = tooltipWindow.implicitHeight
          var point = barWindow.contentItem.mapFromItem(target, target.width / 2 - popupWidth / 2, target.height + 6)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          anchors.centerIn: parent
          text: root.tooltipText
          color: Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
