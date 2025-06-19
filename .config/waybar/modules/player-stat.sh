#!/bin/bash

while true; do
  status="$(playerctl status 2>&1)"

  if [[ "$status" == "Playing" ]]; then
    text="" # Icona PAUSE (quando sta suonando)
    class="playing"
  elif [[ "$status" == "Paused" ]]; then
    text="" # Icona PLAY (quando è in pausa)
    class="paused"
  elif [[ "$status" == "No players found" ]]; then
    text="󰄛" # Nessuna icona se non ci sono player
  else
    # Questo copre lo stato "Stopped" e altri casi
    text="" # Icona PLAY (quando è fermo)
    class="paused"
  fi

  sleep 0.1
  echo "{\"text\":\"$text\", \"class\":\"$class\"}"
done
