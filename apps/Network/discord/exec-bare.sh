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
       --cap-add=CAP_SYS_CHROOT \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e DISPLAY \
       -e XDG_CURRENT_DESKTOP=GNOME \
       -e TERM=xterm \
       -e XTERM_LOCALE=en_US.UTF-8 \
       -e XTERM_SHELL=/usr/bin/bash \
       -e BROSER="falkon" \
       -v $XAUTHORITY:$XAUTHORITY \
       -e XDG_RUNTIME_DIR="/tmp/$USER" \
       -e XAUTHORITY \
       -e vblank_mode \
       --device /dev/dri \
       --device /dev/snd \
       --userns=keep-id \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME" "$@"
