#!/bin/bash

set -e

if [ ! -e ./image.info ]; then
    echo "You first need to run setup.sh to create an image."
    exit 1
fi

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat image.info)"
NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

podman run --rm \
       -w "/home/$USER" \
       --hostname="$NAME" \
       --user="$USER" \
       --cap-drop=ALL \
       --cap-add=sys_chroot \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       -e WAYLAND_DISPLAY \
       -e XDG_RUNTIME_DIR \
       -e XDG_DATA_DIRS \
       -e XDG_CURRENT_DESKTOP=GNOME \
       -e QT_QPA_PLATFORM=wayland \
       -e DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/$USER/run/bus" \
       -e BROWSER="falkon" \
       --userns=keep-id \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       -v "$XDG_RUNTIME_DIR/bus:/tmp/$USER/run/bus" \
       --device /dev/dri \
       --device /dev/snd \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME" "$@"
