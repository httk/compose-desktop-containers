#!/bin/bash

set -e

# If the container is already runs, execute inside the running container so it can discover that it already runs
ID="$(podman ps -q -f "name=office365_container_runtime")"
if [ -n "$ID" ]; then
    echo "App already running; exec inside running container"
    podman exec -it "$ID" bash
    exit 0
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
       -w "/home/$USER" \
       --name "office365_container_runtime" \
       --hostname="$NAME" \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       -e WAYLAND_DISPLAY \
       -e XDG_RUNTIME_DIR="/tmp/$USER" \
       --userns=keep-id \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/$WAYLAND_DISPLAY:ro" \
       -v /dev/dri:/dev/dri \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME"
