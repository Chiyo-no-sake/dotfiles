function text(value) {
  return String(value || "").toLowerCase()
}

function itemNamed(item, name) {
  if (!item) return false
  return text(item.id).indexOf(name) !== -1
    || text(item.title).indexOf(name) !== -1
    || text(item.tooltipTitle).indexOf(name) !== -1
}

// True when a tray item belongs to an app the shell already gives a
// first-party widget, so its icon never also shows in the tray. `ownedApps`
// is a list of app name fragments matched against id/title/tooltip (see
// Tray.qml's ownedApps); an empty or missing list owns nothing.
function ownedByWidget(item, ownedApps) {
  if (!ownedApps) return false
  for (var i = 0; i < ownedApps.length; i++)
    if (itemNamed(item, ownedApps[i])) return true
  return false
}

if (typeof module !== "undefined") {
  module.exports = {
    itemNamed: itemNamed,
    ownedByWidget: ownedByWidget
  }
}
