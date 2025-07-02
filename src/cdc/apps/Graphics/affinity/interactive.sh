#!/bin/bash

set -e

# If the container is already runs, execute inside the running container so it can discover that it already runs
ID="$(podman ps -q -f "name=affinity_container_runtime")"
if [ -n "$ID" ]; then
    echo "App already running; exec inside running container"
    podman exec -it "$ID" bash
    exit 0
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat "$IMAGE_DIR/image.info")"

if ! podman image exists "$IMAGE_NAME"; then
    echo "You first need to create the image: $IMAGE_NAME"
    exit 1
fi

OPT_LINKS=""
for OPT_LINK in opt/*; do
    LINK=$(readlink "$OPT_LINK")
    OPT_LINKS="$OPT_LINKS -v ${IMAGE_DIR}/opt/${LINK}:/${OPT_LINK}:ro"
done
echo opt/*
echo "OPT LINKS: $OPT_LINKS"

mkdir -p "$IMAGE_DIR/home"
#cd "$IMAGE_DIR/home"

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

podman run --rm -it \
       -w "/home/$USER" \
       --name "affinity_container_runtime" \
       --hostname="$NAME" \
       --user="$USER" \
       --shm-size=1G \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       -e XDG_RUNTIME_DIR \
       -e XDG_DATA_DIRS \
       -e BROSER="falkon" \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       --device /dev/dri \
       --userns=keep-id \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e DISPLAY \
       -v $XAUTHORITY:$XAUTHORITY \
       -e XAUTHORITY \
       $FIXES \
       $OPT_LINKS \
       -v "$IMAGE_DIR/files:/files:ro" \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       "$IMAGE_NAME"

#       -v "$IMAGE_DIR/../../setup/" \
