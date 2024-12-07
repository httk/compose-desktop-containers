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
       --user="$USER" \
       --hostname="$NAME" \
       --read-only \
       --shm-size=512M \
       --read-only-tmpfs \
       --systemd=false \
       --cap-drop=ALL \
       --cap-add CAP_SYS_CHROOT \
       --security-opt=no-new-privileges \
       -e LANG \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e DISPLAY \
       -v $XAUTHORITY:$XAUTHORITY \
       -e XAUTHORITY \
       -e XDG_RUNTIME_DIR="/tmp/$USER/run" \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       -v /dev/dri:/dev/dri \
       --userns=keep-id \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME" google-chrome "$@"



# --cap-add=SYS_ADMIN \
#--security-opt seccomp="$IMAGE_DIR/files/chrome.json" \
