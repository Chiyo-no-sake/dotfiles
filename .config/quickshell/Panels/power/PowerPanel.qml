import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "qs.power"
  ipcTarget: "" // custom handler below owns IPC
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the togglePercentage method below.
  manageIpc: false
  property var batteryInfo: ({})
  property var systemInfo: ({})
  property bool cursorActive: false

  // ---- tuned power profile ----
  // No powerprofilesctl on this machine; Fedora's tuned owns the power
  // profile. `tuned-adm active` prints "Current active profile: <name>";
  // empty output (tuned absent) hides the section — the same gate the old
  // powerprofiles picker had (non-empty profile list).
  property string tunedProfile: ""
  property bool tunedAvailable: false
  // Index the keyboard cursor/pending selection points at; -1 = follow the
  // live profile. h/l moves it through the pills, Enter/click applies.
  property int tunedPending: -1
  readonly property var tunedProfiles: [
    { id: "throughput-performance", label: "Performance", glyph: "󰓅" },
    { id: "balanced", label: "Balanced", glyph: "󰗑" },
    { id: "powersave", label: "Power Save", glyph: "󰌪" }
  ]
  readonly property int tunedCurrentIndex: {
    for (var i = 0; i < tunedProfiles.length; i++)
      if (tunedProfiles[i].id === tunedProfile) return i
    return -1
  }
  readonly property int tunedSelectedIndex: tunedPending >= 0 && tunedPending < tunedProfiles.length
    ? tunedPending : tunedCurrentIndex
  readonly property bool showPercentage: setting("showPercentage", false) === true
  // With the percentage shown the button paints a text block wider than an
  // icon, so the open-panel mark takes the painted width instead of the
  // icon-sized fraction of the slot the fallback assumes.
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function refreshTuned() {
    if (!tunedProc.running) tunedProc.running = true
  }

  function updateTunedProfile(raw) {
    var name = String(raw || "").trim()
    if (name === "") {
      tunedAvailable = false
      return
    }
    tunedProfile = name
    tunedAvailable = true
  }

  // Apply a profile directly (click/Enter); keyboard stepping below.
  function applyTunedProfile(id) {
    if (!tunedAvailable || actionProc.running || id === tunedProfile) return
    actionProc.command = ["tuned-adm", "profile", id]
    actionProc.running = true
  }

  // h/l: move the pending selection one pill at a time. No apply until
  // Enter — one tuned-adm (potential polkit prompt) per deliberate change.
  function stepTunedSelection(delta) {
    if (!tunedAvailable) return
    var base = tunedSelectedIndex
    var count = tunedProfiles.length
    tunedPending = ((base + (delta >= 0 ? 1 : -1)) % count + count) % count
  }

  function batteryIcon() {
    var device = UPower.displayDevice
    return Model.batteryIcon(device, root.discharging, upowerStates())
  }

  function modeLabel() {
    var device = UPower.displayDevice
    return Model.modeLabel(device, root.discharging, upowerStates())
  }

  function tunedGlyph() {
    if (tunedProfile === "throughput-performance") return "󰓅"
    if (tunedProfile === "balanced") return "󰗑"
    if (tunedProfile === "powersave") return "󰌪"
    return "󰐥"
  }

  function tunedLabel() {
    if (tunedProfile === "throughput-performance") return "Performance"
    if (tunedProfile === "balanced") return "Balanced"
    if (tunedProfile === "powersave") return "Power Save"
    return tunedProfile !== "" ? tunedProfile.charAt(0).toUpperCase() + tunedProfile.slice(1) : "Power Profile"
  }

  // ---- amphetamine (stay awake) ----
  // The engine (~/.dotfiles/scripts/runtime/amphetamine.sh) kills/respawns
  // hypridle and records state in ~/.cache/amphetamine: "inf", or an epoch
  // expiry. Mirrors of its `status` reconciliation live here so the panel
  // reflects changes instantly: the state file is FileView-watched, and the
  // hypridle liveness probe re-runs on every file change and toggle.
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string amphetamineStatePath: home + "/.cache/amphetamine"
  readonly property string amphetamineEngine: home + "/dotfiles/scripts/runtime/amphetamine.sh"
  property bool amphetamineOn: false
  property bool amphetamineInf: false
  property real amphetamineUntil: 0
  readonly property int amphetamineMinutesLeft: amphetamineInf || !amphetamineOn
    ? 0 : Math.max(0, Math.round((amphetamineUntil - Date.now() / 1000) / 60))

  property string hypridleProbe: ""
  // Flips once the first liveness probe returns, gating the section's
  // visibility so it never flashes in before we know the state.
  property bool amphetamineEverProbed: false

  function refreshAmphetamine() {
    if (!ampProbeProc.running) ampProbeProc.running = true
  }

  // Reconcile file + liveness exactly like the engine's status: a state
  // file with hypridle running is stale (fresh session started), and a
  // past expiry reads as off.
  function reconcileAmphetamine() {
    var text = String(ampStateFile.text() || "").trim()
    var running = hypridleProbe.indexOf("running") !== -1
    if (text === "" || running) {
      amphetamineOn = false
      amphetamineInf = false
      amphetamineUntil = 0
      return
    }
    if (text === "inf") {
      amphetamineOn = true
      amphetamineInf = true
      amphetamineUntil = 0
      return
    }
    var until = parseFloat(text)
    if (isFinite(until) && until > Date.now() / 1000) {
      amphetamineOn = true
      amphetamineInf = false
      amphetamineUntil = until
    } else {
      amphetamineOn = false
      amphetamineInf = false
      amphetamineUntil = 0
    }
  }

  // Optimistic flip + engine round-trip; the exit refresh lands well under
  // the fade animation, so the switch never shows stale state.
  function toggleAmphetamine() {
    amphetamineOn = !amphetamineOn
    ampActionProc.command = ["bash", "-c", "\"" + amphetamineEngine + "\" toggle"]
    ampActionProc.running = true
  }

  function bumpAmphetamine() {
    ampActionProc.command = ["bash", "-c", "\"" + amphetamineEngine + "\" bump 60"]
    ampActionProc.running = true
  }

  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates())
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: batteryFull || chargeThresholdActive

  // 0..1 charge level, used by the visual progress bar.
  readonly property real batteryFraction: {
    var d = UPower.displayDevice
    return Model.batteryFraction(d)
  }

  readonly property bool charging: {
    var d = UPower.displayDevice
    return d && d.isPresent && !UPower.onBattery && !root.batteryFlowIdle
  }

  readonly property color batteryFillColor: {
    return root.bar ? root.bar.foreground : Color.foreground
  }

  // Cute agent-flavored phrases shown in the hero status line, rotated on a
  // timer so the panel feels alive when current is flowing (either direction).
  readonly property var chargingPhrases: [
    "Pumping power",
    "Injecting electrons",
    "Pouring juice",
    "Amassing watts",
    "Hoarding joules",
    "Sucking volts",
    "Topping reserves",
    "Soaking amps",
    "Inhaling kilowatts"
  ]
  readonly property var onBatteryPhrases: [
    "Slurping power",
    "Spending joules",
    "Draining watts",
    "Burning electrons",
    "Sipping juice",
    "Spending coulombs",
    "Bleeding amps",
    "Guzzling volts",
    "Munching reserves"
  ]
  property int phraseIndex: 0

  // Whichever list is "active" given the current power state.
  readonly property var activePhrases: {
    if (fullyCharged) return []
    if (charging) return chargingPhrases
    if (discharging) return onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: activePhrases.length > 0

  readonly property string heroStatusText: {
    if (fullyCharged) return "Fully charged"
    if (rotatingPhrases) return activePhrases[phraseIndex % activePhrases.length]
    return modeLabel()
  }

  function refresh() {
    if (!batteryPresent) return

    if (!batteryProc.running) batteryProc.running = true
    if (!systemProc.running) systemProc.running = true
  }

  function updateKeyValue(raw, targetName) {
    var next = Model.parseKeyValue(raw)
    // Keep last known good data if a refresh briefly returns nothing — happens
    // around AC plug/unplug events. Avoids the section collapsing mid-transition.
    if (Object.keys(next).length === 0) return
    if (targetName === "battery") batteryInfo = next
    else systemInfo = next
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "qs.power"
    enabled: root.manageIpc

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function togglePercentage() { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (opened) {
      if (!batteryPresent) {
        close()
        return
      }

      refresh()
      refreshTuned()
      refreshAmphetamine()
      cursorActive = false
    }
  }

  onBatteryPresentChanged: if (!batteryPresent) close()

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Component.onCompleted: { refreshTuned(); refreshAmphetamine() }

  Process {
    id: batteryProc
    command: ["qs-battery-status", "--shell"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "battery") }
  }

  Process {
    id: tunedProc
    command: ["bash", "-c", "tuned-adm active 2>/dev/null | sed 's/.*: //'"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateTunedProfile(text) }
  }

  Process {
    id: systemProc
    command: ["qs-system-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "system") }
  }

  // tuned-adm apply — one profile switch per run; polkit may prompt.
  Process {
    id: actionProc
    onExited: {
      root.tunedPending = -1
      root.refreshTuned()
    }
  }

  // hypridle liveness for amphetamine reconciliation.
  Process {
    id: ampProbeProc
    command: ["bash", "-c", "if pgrep -x hypridle >/dev/null 2>&1; then echo running; else echo stopped; fi"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.hypridleProbe = String(text || "")
        root.amphetamineEverProbed = true
        root.reconcileAmphetamine()
      }
    }
  }

  // amphetamine engine actions (toggle/bump); refresh on exit catches the
  // engine's own state-file write faster than any poll could.
  Process {
    id: ampActionProc
    onExited: root.refreshAmphetamine()
  }

  FileView {
    id: ampStateFile
    path: root.amphetamineStatePath
    watchChanges: true
    printErrors: false
    onLoaded: root.refreshAmphetamine()
    onLoadFailed: root.refreshAmphetamine()
    onFileChanged: { reload(); root.refreshAmphetamine() }
  }

  // Countdown tick for timed sessions; also expires them visually.
  Timer {
    interval: 30000
    running: root.opened && root.amphetamineOn && !root.amphetamineInf
    repeat: true
    onTriggered: root.reconcileAmphetamine()
  }

  onTunedProfileChanged: tunedPending = -1

  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: { root.refresh(); root.refreshTuned() } }

  // Rotate the status phrase while the panel is open and we're in a
  // rotating state (charging or on battery). The text swap is wrapped in a
  // fade so the changeover reads as one organism rather than a hard cut.
  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    triggeredOnStart: false
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        var n = root.activePhrases.length
        if (n > 0) root.phraseIndex = (root.phraseIndex + 1) % n
      }
    }
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  // If we leave a rotating state mid-swap, halt the animation and snap back
  // to full opacity so "FULLY CHARGED" is legible immediately rather than
  // appearing dimmed.
  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showPercentage && !vertical
      ? Math.round(root.batteryFraction * 100) + "% " + root.batteryIcon()
      : root.batteryIcon()
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        var delta = dx !== 0 ? dx : dy
        if (delta !== 0) root.stepTunedSelection(delta)
      }
      onActivateRequested: if (root.cursorActive && root.tunedSelectedIndex >= 0) root.applyTunedProfile(root.tunedProfiles[root.tunedSelectedIndex].id)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: battery icon · title/status · percentage ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            text: root.batteryIcon()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Battery"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroStatus
              text: root.heroStatusText.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            text: root.batteryInfo.percentage || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        // ---------- Battery progress bar ----------
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.batteryFillColor
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            // Subtle pulse while charging — visible signal that energy is flowing in.
            SequentialAnimation on opacity {
              running: root.charging && !root.fullyCharged && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
          }
        }

        // ---------- Stats ----------
        // Visibility is intentionally only gated by "we've ever loaded data" so
        // the section never collapses mid-transition. fullyCharged is *not* part
        // of the condition: UPower briefly reports FullyCharged on plug-in when
        // the battery sits above the charge-control start threshold, and we
        // refuse to flicker the whole panel for that ~1s window.
        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Battery size"; value: root.batteryInfo.size || "" }
            InfoPair { label: "Charge cycles"; value: root.batteryInfo.cycles || "—" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: root.chargeThresholdActive ? "Charge limit" : (root.discharging ? "Time left" : "Time to full")
              value: root.chargeThresholdActive ? (root.batteryInfo.threshold || "-") : (root.batteryFlowIdle ? "-" : (root.batteryInfo.time || "—"))
            }
            InfoPair {
              label: root.chargeThresholdActive ? "Battery state" : (root.discharging ? "Discharging" : "Charging")
              value: root.chargeThresholdActive ? "Holding" : (root.batteryFull ? "-" : (root.batteryInfo.rate || ""))
            }
          }
        }

        // ---------- Power profile (tuned) ----------
        // Fedora's tuned owns the profile here. One row shows the active
        // profile; click, Enter, or the arrows cycle it. Apply is immediate
        // — one tuned-adm call per step, and polkit may prompt per change.
        PanelSeparator {
          visible: root.tunedAvailable
          foreground: root.bar.foreground
        }

        Column {
          visible: root.tunedAvailable
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "POWER PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Grid {
            id: tunedRow
            width: parent.width
            columns: root.tunedProfiles.length
            spacing: Style.spacing.xs

            readonly property real cellWidth: root.tunedProfiles.length > 0
              ? (width - spacing * (columns - 1)) / columns
              : 0

            Repeater {
              model: root.tunedProfiles

              ProfilePill {
                required property var modelData
                required property int index

                profile: modelData
                pillIndex: index
                width: tunedRow.cellWidth
              }
            }
          }
        }

        // ---------- Stay awake (amphetamine) ----------
        // Keep-awake for hypridle, driven by the user's amphetamine engine.
        // Toggle flips indefinite mode; +60m extends (or starts) a timed
        // session. State is file-watched, so external changes (the CLI,
        // the old bar widget) reflect here instantly too.
        PanelSeparator {
          visible: root.amphetamineEverProbed
          foreground: root.bar.foreground
        }

        Column {
          visible: root.amphetamineEverProbed
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(awakeHeaderRow.implicitHeight, awakeSwitch.implicitHeight)

            Row {
              id: awakeHeaderRow
              spacing: Style.space(6)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: root.amphetamineOn ? "" : "󰛨"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                anchors.verticalCenter: awakeHeader.verticalCenter
                anchors.verticalCenterOffset: Math.round(awakeHeader.topPadding / 2)
              }

              PanelSectionHeader {
                id: awakeHeader
                text: "STAY AWAKE"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }
            }

            Row {
              spacing: Style.space(8)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter

              Text {
                visible: root.amphetamineOn
                text: root.amphetamineInf ? "until off" : root.amphetamineMinutesLeft + "m left"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Button {
                visible: root.amphetamineOn
                text: "+60m"
                fontSize: Style.font.caption
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.sm
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                tooltipText: "Extend the session by 60 minutes"
                onClicked: root.bumpAmphetamine()
              }

              ToggleSwitch {
                id: awakeSwitch
                checked: root.amphetamineOn
                foreground: root.bar.foreground
                onToggled: root.toggleAmphetamine()

                PanelToolTip {
                  visible: awakeSwitch.containsMouse
                  text: root.amphetamineOn ? "Staying awake — click to resume idle timeouts" : "Idle timeouts active — click to stay awake"
                  fontFamily: root.bar.fontFamily
                }
              }
            }
          }
        }
      }
    }
  }

  component ProfilePill: Button {
    id: pill
    required property var profile
    required property int pillIndex

    text: profile.label
    fontSize: Style.font.caption
    foreground: root.bar.foreground
    fontFamily: root.bar.fontFamily
    horizontalPadding: Style.spacing.sm
    verticalPadding: Style.spacing.controlPaddingY
    bordered: true

    active: root.tunedProfile === profile.id
    hasCursor: root.cursorActive && root.tunedSelectedIndex === pill.pillIndex

    onClicked: root.applyTunedProfile(profile.id)
    onHovered: function(isHovered) {
      if (!isHovered) return
      root.cursorActive = true
      root.tunedPending = pill.pillIndex
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
