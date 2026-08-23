#!/usr/bin/env bash

set -u

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprwhspr"
control_fifo="$runtime_dir/recording_control"
status_file="$runtime_dir/recording_status"
action="${1:-}"

send_command() {
    local command="$1"

    [[ -p "$control_fifo" ]] || exit 0
    printf '%s\n' "$command" > "$control_fifo"
}

case "$action" in
    start)
        send_command start
        ;;
    stop)
        # A very short press can release while the daemon is still handling
        # startup. Wait for recording to become active, then request its stop.
        for _ in {1..30}; do
            if [[ -f "$status_file" ]] && [[ "$(<"$status_file")" == "true" ]]; then
                for _ in {1..30}; do
                    send_command stop
                    sleep 0.1
                    [[ -f "$status_file" ]] || exit 0
                    [[ "$(<"$status_file")" == "true" ]] || exit 0
                done
                exit 1
            fi
            sleep 0.1
        done
        exit 1
        ;;
    *)
        printf 'Usage: %s {start|stop}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
