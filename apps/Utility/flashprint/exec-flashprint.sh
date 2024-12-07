#!/bin/bash

set -e

# If the container is already runs, execute inside the running container so it can discover that it already runs
ID="$(podman ps -q -f "name=flashprint_container_runtime")"
if [ -n "$ID" ]; then
    echo "App already running; exec inside running container"
    podman exec "$ID" bash -c "LD_LIBRARY_PATH=/home/$USER/flashprint/flashprint/usr/lib exec /home/$USER/flashprint/flashprint/usr/share/FlashPrint5/FlashPrint" "$@"
    exit 0
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat "$IMAGE_DIR/image.info")"

if ! podman image exists "$IMAGE_NAME"; then
    echo "You first need to create the image: $IMAGE_NAME"
    exit 1
fi

mkdir -p "$IMAGE_DIR/home"
cd "$IMAGE_DIR/home"

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

podman run --rm \
       -w "/home/$USER" \
       --name "flashprint_container_runtime" \
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
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME" bash -c "MESA_DEBUG=1 LD_LIBRARY_PATH=/home/$USER/flashprint/flashprint/usr/lib exec /home/$USER/flashprint/flashprint/usr/share/FlashPrint5/FlashPrint" "$@"

#      -e QT_QPA_PLATFORM=wayland \
#       -e QT_WAYLAND_RECONNECT=1 \
#       -e WAYLAND_DISPLAY \


#       --cap-add=CAP_SYS_CHROOT \
#       --device /dev/snd \
#       -v /tmp/.X11-unix:/tmp/.X11-unix \
#       -e DISPLAY \
#       -v $XAUTHORITY:$XAUTHORITY \
#       -e XAUTHORITY \


#       "$IMAGE_NAME" bash -c "cd flashprint/Flashprint; pipewire-pulse & ./Flashprint --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland" "$@"

#       -e TERM=xterm \
#       -e XTERM_LOCALE=en_US.UTF-8 \
#       -e XTERM_SHELL=/usr/bin/bash \
# -v "$XDG_RUNTIME_DIR/bus:/tmp/$USER/run/bus" \
#  -e DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/$USER/run/bus" \

# pipewire-pulse &

# "$IMAGE_NAME" bash -c "cd zoom/zoom; systemctl --user start wireplumber pipewire pipewire-pulse && LD_LIBRARY_PATH=/home/rar/zoom/zoom:/home/rar/zoom/zoom/Qt/lib exec ./zoom" "$@"
