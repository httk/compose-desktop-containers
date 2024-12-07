#!/bin/bash

set -e

# If the container is already runs, execute inside the running container so it can discover that it already runs
ID="$(podman ps -q -f "name=slack_container_runtime")"
if [ -n "$ID" ]; then
    echo "App already running; exec inside running container"
    podman exec "$ID" bash -c 'cd slack/slack; usr/bin/slack "$@"' bash "$@"
    exit 0
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat "$IMAGE_DIR/image.info")"

mkdir -p "$IMAGE_DIR/home"
cd "$IMAGE_DIR/home"

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

VIDEO_DEVS=""
for DEV in /dev/video*; do
    if [ -c $DEV ]; then
      VIDEO_DEVS="--device $DEV $VIDEO_DEVS"
    fi
done

NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

podman run --rm \
       -w "/home/$USER" \
       --name "slack_container_runtime" \
       --hostname="$NAME" \
       --user="$USER" \
       --shm-size=512M \
       --cap-drop=ALL \
       --cap-add=CAP_SYS_CHROOT \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e QT_WAYLAND_RECONNECT=1 \
       -e LANG \
       -e WAYLAND_DISPLAY \
       -e XDG_RUNTIME_DIR \
       -e XDG_DATA_DIRS \
       -e XDG_CURRENT_DESKTOP=GNOME \
       -e QT_QPA_PLATFORM=wayland \
       -e BROWSER="falkon" \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       --device /dev/dri \
       --device /dev/snd \
       --userns=keep-id \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e DISPLAY \
       -v $XAUTHORITY:$XAUTHORITY \
       -e XAUTHORITY \
       $VIDEO_DEVS \
       $FIXES \
       "$IMAGE_NAME" bash -c 'cd slack/slack; pipewire-pulse & usr/bin/slack "$@"' bash "$@"

#       "$IMAGE_NAME" bash -c "cd discord/Discord; pipewire-pulse & ./Discord --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland" "$@"

#       -e TERM=xterm \
#       -e XTERM_LOCALE=en_US.UTF-8 \
#       -e XTERM_SHELL=/usr/bin/bash \
# -v "$XDG_RUNTIME_DIR/bus:/tmp/$USER/run/bus" \
#  -e DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/$USER/run/bus" \

# pipewire-pulse &

# "$IMAGE_NAME" bash -c "cd zoom/zoom; systemctl --user start wireplumber pipewire pipewire-pulse && LD_LIBRARY_PATH=/home/rar/zoom/zoom:/home/rar/zoom/zoom/Qt/lib exec ./zoom" "$@"
