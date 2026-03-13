#!/bin/bash

# Network speed monitor for waybar
# Shows download and upload speed

INTERFACE=$(ip route | awk '/default/ {print $5; exit}')

if [[ -z "$INTERFACE" ]]; then
    echo "󰖪 --"
    exit 0
fi

# Read current bytes
RX1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null)
TX1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null)

sleep 1

# Read bytes after 1 second
RX2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null)
TX2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null)

# Calculate speed (bytes per second)
RX_SPEED=$((RX2 - RX1))
TX_SPEED=$((TX2 - TX1))

# Format speed with appropriate unit
format_speed() {
    local speed=$1
    if [[ $speed -lt 1024 ]]; then
        printf "%4s" "${speed}B"
    elif [[ $speed -lt 1048576 ]]; then
        printf "%4s" "$(( speed / 1024 ))K"
    else
        printf "%4s" "$(( speed / 1048576 ))M"
    fi
}

DOWN=$(format_speed $RX_SPEED)
UP=$(format_speed $TX_SPEED)

# Icons:  (download)  (upload)
echo "󰁆 $DOWN 󰁞 $UP"
