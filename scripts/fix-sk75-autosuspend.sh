#!/usr/bin/env bash
# Stop the RDR SK75 keyboard (320f:5055) from sleeping via USB autosuspend.
# Adds a persistent udev rule (matching the existing 50-no-autosuspend.rules
# entries) and applies the fix to the currently-connected device immediately.
set -euo pipefail

RULES_FILE=/etc/udev/rules.d/50-no-autosuspend.rules
DEV=/sys/bus/usb/devices/3-5.1   # SK75's current USB path

echo "==> Adding SK75 to $RULES_FILE (if not already present)"
if ! sudo grep -q '320f.*5055' "$RULES_FILE" 2>/dev/null; then
  sudo tee -a "$RULES_FILE" >/dev/null <<'EOF'
# RDR SK75 Keyboard
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="320f", ATTR{idProduct}=="5055", ATTR{power/autosuspend}="-1"
EOF
  echo "    added."
else
  echo "    already present, skipping."
fi

echo "==> Reloading udev rules"
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=320f

echo "==> Applying live fix to currently-connected SK75"
if [ -e "$DEV/power/control" ]; then
  echo on | sudo tee "$DEV/power/control" >/dev/null
  echo -1 | sudo tee "$DEV/power/autosuspend_delay_ms" >/dev/null
else
  echo "    $DEV not found (keyboard moved ports?); rule still applies on next plug-in."
fi

echo "==> Result"
echo "    control:        $(cat "$DEV/power/control" 2>/dev/null || echo n/a)"
echo "    runtime_status: $(cat "$DEV/power/runtime_status" 2>/dev/null || echo n/a)"
echo "Done. Expect control=on and runtime_status=active."
