#!/bin/bash

# Toggle region screen recording with wf-recorder (bound to Super+Shift+\).
# First press: slurp a region and record to ~/Videos. Press again: stop, save,
# and copy the MP4 itself to the Wayland clipboard.
# Requires: wf-recorder, slurp, wl-copy.

PIDFILE="/tmp/wf-recorder.pid"
OUTFILE="/tmp/wf-recorder.output"
OUTDIR="${XDG_VIDEOS_DIR:-$HOME/Videos}"
mkdir -p "$OUTDIR"

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  pid="$(cat "$PIDFILE")"
  kill -INT "$pid" 2>/dev/null || true

  for _ in {1..100}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.05
  done

  if kill -0 "$pid" 2>/dev/null; then
    notify-send "Screen Record" "Stopping recording…"
    exit 0
  fi

  if [[ -s "$OUTFILE" ]] && [[ -f "$(cat "$OUTFILE")" ]]; then
    out="$(cat "$OUTFILE")"
    wl-copy --type video/mp4 < "$out"
    notify-send "Screen Record" "Saved and copied to clipboard"
  else
    notify-send "Screen Record" "Saved"
  fi

  rm -f "$PIDFILE" "$OUTFILE"
else
  geom="$(slurp)" || exit 0
  out="$OUTDIR/rec-$(date +%s).mp4"
  wf-recorder -g "$geom" -f "$out" &
  echo $! > "$PIDFILE"
  printf '%s\n' "$out" > "$OUTFILE"
  notify-send "Screen Record" "Recording region… press Super+Shift+\\ to stop"
fi
