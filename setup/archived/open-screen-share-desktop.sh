#!/bin/bash

cleanup() {
    # kill all processes whose parent is this process
    pkill -P $$
}

for sig in INT QUIT HUP TERM; do
  trap "
    cleanup
    trap - $sig EXIT
    kill -s $sig "'"$$"' "$sig"
done
trap cleanup EXIT

Xwayland -noreset -decorate :101 &

env -u WAYLAND_DISPLAY GDK_BACKEND=x11 XDG_SESSION_TYPE=x11  QT_QPA_PLATFORM=x11 SDL_VIDEODRIVER=x11 DISPLAY=:101 openbox
