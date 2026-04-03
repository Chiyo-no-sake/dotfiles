#!/bin/bash
# Power profile display/cycle for Waybar (uses tuned-adm)

get_profile() {
    tuned-adm active 2>/dev/null | sed 's/.*: //'
}

if [ "$1" = "cycle" ]; then
    current=$(get_profile)
    case "$current" in
        throughput-performance) tuned-adm profile balanced ;;
        balanced)              tuned-adm profile powersave ;;
        powersave)             tuned-adm profile throughput-performance ;;
        *)                     tuned-adm profile balanced ;;
    esac
fi

profile=$(get_profile)
case "$profile" in
    throughput-performance) echo " " ;;
    balanced*)              echo "󰗑 " ;;
    powersave)              echo "󰌪 " ;;
    *)                      echo "󰗑 " ;;
esac
