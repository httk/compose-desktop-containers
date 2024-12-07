#!/bin/bash

set -e

if [ ! -e ./image.info ]; then
    echo "You first need to run setup.sh to create an image."
    exit 1
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)

podman run --rm \
       --user="$USER" \
       --hostname="$(cat image.info)" \
       --shm-size=256M \
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
	-e XDG_RUNTIME_DIR="/tmp/$USER" \
	--userns=keep-id \
	-v /dev/dri:/dev/dri \
	-v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/$WAYLAND_DISPLAY:ro" \
	-v "$IMAGE_DIR/home:/home/$USER:rw" \
        "$(cat image.info)" "$@"

#       --security-opt=no-new-privileges \
