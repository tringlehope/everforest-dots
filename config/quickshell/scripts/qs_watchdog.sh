#!/usr/bin/env bash

start_qs() {
    if ! pgrep -x qs >/dev/null 2>&1; then
        qs > /tmp/qs.log 2>&1 &
    fi
}

restart_on_wake() {
    for _ in $(seq 1 20); do
        if hyprctl monitors 2>/dev/null | grep -q "Monitor " && ! hyprctl monitors 2>/dev/null | grep -q "FALLBACK"; then
            break
        fi
        sleep 0.5
    done
    sleep 0.5
    pkill -x qs 2>/dev/null || true
    sleep 0.3
    qs > /tmp/qs.log 2>&1 &
}

start_qs

(
    gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 2>/dev/null | \
    while IFS= read -r line; do
        if [[ "$line" == *"PrepareForSleep (false,)"* ]]; then
            restart_on_wake
        fi
    done
) &

while true; do
    sleep 3
    start_qs
done
