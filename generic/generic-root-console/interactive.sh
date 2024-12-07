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

podman run --rm -it \
       -w "/" \
       --shm-size=512M \
       --user root \
       --hostname="$NAME" \
       --cap-drop=ALL \
       --cap-add=CAP_SYS_CHROOT \
       --cap-add=CAP_FOWNER \
       --cap-add=CAP_CHOWN \
       --cap-add=CAP_DAC_OVERRIDE \
       --cap-add=CAP_DAC_READ_SEARCH \
       --cap-add=CAP_SETUID \
       --cap-add=CAP_SETGID \
       -e XDG_CURRENT_DESKTOP=GNOME \
       -e BROSER="falkon" \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e XDG_RUNTIME_DIR="/tmp/$USER" \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/$WAYLAND_DISPLAY:ro" \
       -e WAYLAND_DISPLAY \
       -e DISPLAY \
       -e XAUTHORITY \
       -v $XAUTHORITY:$XAUTHORITY \
       --read-only=false \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       --read-only=false \
       --read-only-tmpfs \
       --systemd=false \
       --userns=keep-id \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME"

podman image prune -f
