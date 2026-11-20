#!/usr/bin/env bash
rm -f /tmp/hypr-scroll-stop
prev_x=$(hyprctl cursorpos -j | python3 -c "import sys,json; print(json.load(sys.stdin)['x'])")
while [ ! -f /tmp/hypr-scroll-stop ]; do
    cur_x=$(hyprctl cursorpos -j | python3 -c "import sys,json; print(json.load(sys.stdin)['x'])")
    dx=$((cur_x - prev_x))
    if [ "$dx" -ne 0 ]; then
        hyprctl dispatch "hl.dsp.layout('move $dx')" >/dev/null 2>&1
        prev_x=$cur_x
    fi
    sleep 0.016
done
