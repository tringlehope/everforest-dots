#!/usr/bin/env bash
id=$(hyprctl activeworkspace -j | grep -m1 '"id":' | tr -dc '0-9')
id=${id:-1}
next=$((id + ${1:-0}))
[ "$next" -ge 1 ] && [ "$next" -le 9 ] && hyprctl dispatch "hl.dsp.focus({ workspace = $next })"
