#!/usr/bin/env bash
# amphetamine.sh — keep-awake toggle for hypridle (a "caffeine" clone).
#
# hypridle (v0.1.7) has no IPC, so "on" simply kills the daemon and "off"
# respawns it via `hyprctl dispatch exec` so the new process is parented to
# Hyprland, not the caller — a waybar reload would otherwise take hypridle
# down with it.
#
# State lives in ~/.cache/amphetamine: "inf" for indefinite, or an
# epoch-seconds expiry for timed sessions. `status` reconciles stale state:
# if the file says "on" but hypridle is running, a new session has started
# (exec-once relaunched it at login), so the state is cleared.

set -u

STATE="$HOME/.cache/amphetamine"

hypridle_running() { pgrep -x hypridle >/dev/null; }

kill_hypridle() {
    pkill -x hypridle 2>/dev/null
    # wait for it to die so `status` never sees "on" + running and
    # misreads it as a stale state file
    for _ in {1..20}; do
        hypridle_running || return 0
        sleep 0.05
    done
}

start_hypridle() {
    hypridle_running || hyprctl dispatch exec hypridle >/dev/null
}

case "${1:-status}" in
    on)
        mins="${2:-0}"
        kill_hypridle
        if (( mins > 0 )); then
            echo $(( $(date +%s) + mins * 60 )) > "$STATE"
        else
            echo inf > "$STATE"
        fi
        ;;
    off)
        rm -f "$STATE"
        start_hypridle
        ;;
    toggle)
        if [[ -f "$STATE" ]]; then exec "$0" off; else exec "$0" on "${2:-0}"; fi
        ;;
    bump)
        # extend a timed session by N minutes, or start one; an indefinite
        # session is already maximal, leave it alone
        mins="${2:-60}"
        now=$(date +%s)
        until=$(cat "$STATE" 2>/dev/null || true)
        if [[ "$until" == inf ]]; then
            exit 0
        elif [[ "$until" =~ ^[0-9]+$ ]] && (( until > now )); then
            echo $(( until + mins * 60 )) > "$STATE"
        else
            exec "$0" on "$mins"
        fi
        ;;
    status)
        # prints "off", "inf", or remaining seconds; expires timed sessions
        [[ -f "$STATE" ]] || { echo off; exit 0; }
        if hypridle_running; then
            rm -f "$STATE"
            echo off
            exit 0
        fi
        until=$(cat "$STATE")
        if [[ "$until" == inf ]]; then
            echo inf
        elif (( until <= $(date +%s) )); then
            "$0" off
            echo off
        else
            echo $(( until - $(date +%s) ))
        fi
        ;;
    *)
        echo "usage: $(basename "$0") {on [min]|off|toggle|bump [min]|status}" >&2
        exit 1
        ;;
esac
