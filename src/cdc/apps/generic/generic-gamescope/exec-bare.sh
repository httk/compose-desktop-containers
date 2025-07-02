#!/bin/bash

set -e

if [ ! -e ./image.info ]; then
    echo "You first need to run setup.sh to create an image."
    exit 1
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)

podman run --rm \
       -w "/home/$USER" \
       --hostname="$NAME" \
       --user="$USER" \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
	--userns=keep-id \
	-e WAYLAND_DISPLAY \
	-e XDG_RUNTIME_DIR=/tmp \
	--userns=keep-id \
	-v /dev/dri:/dev/dri \
	-v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY:ro" \
	-v "$IMAGE_DIR/home:/home/$USER:rw" \
        "$IMAGE_NAME" "$@"
