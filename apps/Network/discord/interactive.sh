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

VIDEO_DEVS=""
for DEV in /dev/video*; do
    if [ -c $DEV ]; then
      VIDEO_DEVS="--device $DEV $VIDEO_DEVS"
    fi
done

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat image.info)"
NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

podman run --rm -it \
       -w "/home/$USER" \
       --hostname="$NAME" \
       --user="$USER" \
       --shm-size=512M \
       --cap-drop=ALL \
       --cap-add=CAP_SYS_CHROOT \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       -e XDG_RUNTIME_DIR \
       -e XDG_DATA_DIRS \
       -e XDG_CURRENT_DESKTOP=GNOME \
       -e DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/$USER/run/bus" \
       -e BROSER="falkon" \
       -e TERM=xterm \
       -e XTERM_LOCALE=en_US.UTF-8 \
       -e XTERM_SHELL=/usr/bin/bash \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e DISPLAY \
       -v $XAUTHORITY:$XAUTHORITY \
       -e XAUTHORITY \
       -v "$XDG_RUNTIME_DIR/bus:/tmp/$USER/run/bus" \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       --device /dev/dri \
       --device /dev/snd \
       --userns=keep-id \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $VIDEO_DEVS \
       $FIXES \
       "$IMAGE_NAME"

#       -v $XAUTHORITY:$XAUTHORITY \
