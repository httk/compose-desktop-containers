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

#       --security-opt=no-new-privileges \

podman run --rm \
       -w "/home/$USER" \
       --hostname="$NAME" \
       --user="$USER" \
       --hostname="$(cat image.info)" \
       --shm-size=512M \
       --cap-drop=ALL \
       --cap-add SETGID \
       --cap-add SETUID \
       --cap-add SYS_CHROOT \
       --cap-add SYS_PTRACE \
       --cap-add=NET_ADMIN \
       --cap-add=SYS_ADMIN \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       -e LANG \
       --userns=keep-id \
       -e WAYLAND_DISPLAY \
       -e XDG_RUNTIME_DIR="/tmp/$USER/run" \
       --userns=keep-id \
       -v /dev/dri:/dev/dri \
       -v /dev/snd:/dev/snd \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       "$IMAGE_NAME" "$@"
