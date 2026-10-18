#!/usr/bin/env bash

# Add this script to your wm startup file.

DIR="$HOME/.config/polybar/blocky"

# Terminate already running bar instances
pkill polybar
pkill xfce4-panel
# killall -q polybar
# killall -q xfce4-panel
# Wait until the processes have been shut down
# while pgrep -u $UID -x xfce4-panel >/dev/null; do sleep 1; done
# while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch the bar
polybar -q main -c "$DIR"/config.ini &
# polybar -q right -c "$DIR"/config.ini &
# polybar -q left -c "$DIR"/config.ini &
