#!/usr/bin/env bash
if [ "$(cat "$HOME/.local/state/qs-theme" 2>/dev/null)" = "win7" ] && command -v nemo &>/dev/null; then
    exec nemo "$@"
else
    exec nautilus "$@"
fi
