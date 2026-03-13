#!/bin/bash

# CPU sparkline monitor for waybar
# Shows a rolling 15-sample sparkline + percentage

HISTORY_FILE="/tmp/waybar-cpu-history-$(id -u)"
BLOCKS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
MAX_ENTRIES=6

# Read CPU usage via /proc/stat differential
read_cpu() {
    awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat
}

read -r TOTAL1 IDLE1 <<< "$(read_cpu)"
sleep 0.2
read -r TOTAL2 IDLE2 <<< "$(read_cpu)"

DELTA_TOTAL=$((TOTAL2 - TOTAL1))
DELTA_IDLE=$((IDLE2 - IDLE1))

if [[ $DELTA_TOTAL -gt 0 ]]; then
    CPU_PCT=$(( (DELTA_TOTAL - DELTA_IDLE) * 100 / DELTA_TOTAL ))
else
    CPU_PCT=0
fi

# Append to history
echo "$CPU_PCT" >> "$HISTORY_FILE"

# Keep only last MAX_ENTRIES lines
tail -n "$MAX_ENTRIES" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

# Read history
mapfile -t READINGS < "$HISTORY_FILE"
COUNT=${#READINGS[@]}

# Build sparkline: left-pad with ▁ if fewer than MAX_ENTRIES
SPARK=""
for (( i = 0; i < MAX_ENTRIES - COUNT; i++ )); do
    SPARK+="▁"
done
for val in "${READINGS[@]}"; do
    idx=$(( val * 7 / 100 ))
    (( idx > 7 )) && idx=7
    (( idx < 0 )) && idx=0
    SPARK+="${BLOCKS[$idx]}"
done

printf "%s%3d%%\n" "$SPARK" "$CPU_PCT"
