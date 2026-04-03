const THEME_NAME = "Matugen Dynamic Theme";
const POLL_SECONDS = 5;

let lastVersion = null;

async function getThemeExtension() {
  const extensions = await chrome.management.getAll();
  return extensions.find(
    (ext) => ext.name === THEME_NAME && ext.type === "theme"
  );
}

async function checkForUpdate() {
  const theme = await getThemeExtension();
  if (!theme) return;

  if (lastVersion === null) {
    lastVersion = theme.version;
    return;
  }

  if (theme.version !== lastVersion) {
    lastVersion = theme.version;
    // Toggle off then on to force Chrome to re-read the theme
    await chrome.management.setEnabled(theme.id, false);
    await chrome.management.setEnabled(theme.id, true);
  }
}

chrome.alarms.create("check-theme", { periodInMinutes: POLL_SECONDS / 60 });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "check-theme") {
    checkForUpdate();
  }
});

// Also check on startup
checkForUpdate();
