import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Clipboard history panel. Reads the same cliphist store the session
// already captures into (wl-paste --watch cliphist store), so it is a
// viewer over existing data, not a second manager. Rows copy on click,
// right-click/x deletes, the footer wipes. Search filters previews.
//
// cliphist's own line format is preserved verbatim per row ("index\tpreview
// [[ binary data ... ]]") because both `decode` and `delete` want the raw
// line back — indices alone shift after every mutation.
Panel {
  id: root
  moduleName: "qs.clipboard"
  ipcTarget: "qs.clipboard"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string cliphist: home + "/dotfiles/.local/share/bin/cliphist"
  readonly property string wlCopy: home + "/dotfiles/.local/share/bin/wl-copy"

  property var rawLines: []
  property var rows: []
  property string query: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  readonly property int entryCount: rawLines.length
  readonly property color hoverFill: bar
    ? Style.hoverFillFor(bar.foreground, Color.accent)
    : "transparent"
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(bar.foreground, Color.accent)
    : "transparent"

  // Row shape: { raw, preview, isImage, glyph }
  function rebuildRows() {
    var out = []
    var needle = query.trim().toLowerCase()
    for (var i = 0; i < rawLines.length; i++) {
      var raw = String(rawLines[i])
      var preview = raw.replace(/^\d+\t/, "")
      var isImage = preview.indexOf("[[ binary data") !== -1
      if (isImage) preview = preview.substring(0, preview.indexOf("[[ binary data")).trim()
      preview = preview.replace(/\s+/g, " ").substring(0, 120)
      var text = isImage ? "image screenshot" : preview.toLowerCase()
      if (needle && text.indexOf(needle) === -1) continue
      out.push({
        raw: raw,
        preview: preview.length > 0 ? preview : (isImage ? "Image" : "(empty)"),
        isImage: isImage,
        glyph: isImage ? "󰋊" : "󰅍"
      })
      if (out.length >= 50) break
    }
    rows = out
    if (selectedIndex >= rows.length) selectedIndex = rows.length - 1
    if (selectedIndex < 0) selectedIndex = 0
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function copyEntry(row) {
    if (!row) return
    copyProc.command = ["bash", "-c",
      "printf '%s' " + Util.shellQuote(row.raw) + " | '" + cliphist + "' decode | '" + wlCopy + "'"]
    copyProc.running = true
    root.close()
  }

  function deleteEntry(index) {
    if (index < 0 || index >= rows.length) return
    deleteProc.command = ["bash", "-c",
      "printf '%s' " + Util.shellQuote(rows[index].raw) + " | '" + cliphist + "' delete"]
    deleteProc.running = true
  }

  function wipe() {
    wipeProc.command = ["bash", "-c", "'" + cliphist + "' wipe"]
    wipeProc.running = true
  }

  onOpenedChanged: if (opened) { query = ""; refresh() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: listProc
    command: ["bash", "-c", "'" + root.cliphist + "' list 2>/dev/null || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var text = String(this.text || "")
        root.rawLines = text.trim().length > 0 ? text.split("\n") : []
        root.rebuildRows()
      }
    }
  }

  Process {
    id: copyProc
    stdout: StdioCollector { waitForEnd: true }
  }

  Process {
    id: deleteProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: root.refresh()
  }

  Process {
    id: wipeProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.entryCount > 0 ? "󰅍 " + root.entryCount : "󰅍"
    tooltipText: "Clipboard history — click to pick\nclick row: copy · right/x: delete"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(listColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) {
          root.selectedIndex = Math.max(0, Math.min(root.rows.length - 1, root.selectedIndex + dy))
          root.ensureVisible(root.selectedIndex)
        }
      }
      onActivateRequested: if (root.cursorActive) root.copyEntry(root.rows[root.selectedIndex])
      onCloseRequested: root.close()
      onDeleteRequested: root.deleteEntry(root.selectedIndex)
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        // Any printable char jumps into the search box with that char.
        searchField.forceActiveFocus()
        searchField.text = root.query + t
        searchField.cursorPosition = searchField.text.length
      }

      Column {
        id: listColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        // ---- search ----
        TextField {
          id: searchField
          width: parent.width
          foreground: root.bar.foreground
          placeholderText: "Search clipboard…"
          font.family: root.bar.fontFamily
          onTextChanged: { root.query = text; root.rebuildRows() }

          Keys.onPressed: function(event) {
            // Arrows navigate while typing; letters must keep typing.
            if (event.key === Qt.Key_Down) {
              root.selectedIndex = Math.min(root.rows.length - 1, root.selectedIndex + 1)
              root.ensureVisible(root.selectedIndex)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.selectedIndex = Math.max(0, root.selectedIndex - 1)
              root.ensureVisible(root.selectedIndex)
              event.accepted = true
            }
          }
          // Enter copies the selected row; Escape clears, then closes.
          onAccepted: root.copyEntry(root.rows[root.selectedIndex])
          Keys.onEscapePressed: function(event) {
            if (text.length > 0) { text = "" }
            else root.close()
            event.accepted = true
          }
        }

        // ---- list ----
        ListView {
          id: historyList
          width: parent.width
          height: Math.min(contentHeight, Style.space(380))
          clip: true
          spacing: Style.spacing.xs
          model: root.rows

          delegate: ClipboardRow {
            required property var modelData
            required property int index
            width: historyList.width
            rowData: modelData
            rowIndex: index
          }

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }

        // ---- footer ----
        Row {
          id: footerRow
          width: parent.width
          spacing: Style.space(8)

          Text {
            id: countLabel
            text: root.entryCount + " entries"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Item { width: Math.max(0, footerRow.width - countLabel.implicitWidth - wipeButton.implicitWidth - footerRow.spacing * 2); height: 1 }

          Button {
            id: wipeButton
            text: "Wipe"
            fontSize: Style.font.caption
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.sm
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            tooltipText: "Clear the entire clipboard history"
            onClicked: root.wipe()
          }
        }

        Text {
          visible: root.rows.length === 0
          text: root.query.length > 0 ? "No matches" : "Clipboard history is empty"
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
          topPadding: Style.space(10)
        }
      }
    }
  }


  function ensureVisible(index) {
    if (index < 0) return
    var rowH = Style.spacing.controlHeight + Style.spacing.xs
    var y = index * rowH
    if (y < historyList.contentY) historyList.contentY = y
    else if (y + rowH > historyList.contentY + historyList.height)
      historyList.contentY = y + rowH - historyList.height
  }

  component ClipboardRow: CursorSurface {
    id: row
    required property var rowData
    required property int rowIndex

    hasCursor: root.cursorActive && root.selectedIndex === rowIndex
    current: root.selectedIndex === rowIndex
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: rowInner.implicitHeight + Style.spacing.rowGap

    Row {
      id: rowInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: row.rowData.glyph
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: row.rowData.preview
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        width: parent.width - Style.space(16) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    HoverHandler {
      onHoveredChanged: if (hovered) {
        root.cursorActive = true
        root.selectedIndex = row.rowIndex
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.deleteEntry(row.rowIndex)
        else root.copyEntry(row.rowData)
      }
    }
  }
}
