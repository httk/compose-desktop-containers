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

WIDTH=$(xdpyinfo | awk '/dimensions/ {print $2}' | awk -Fx '{print int(0.85*$1)}')
HEIGHT=$(xdpyinfo | awk '/dimensions/ {print $2}' | awk -Fx '{print int(0.85*$2)}')

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat image.info)"
NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

echo "Executing steam at resolution $WIDTH x $HEIGHT"

podman run --rm \
       -w "/home/$USER" \
       --hostname="$NAME" \
       --user="$USER" \
       --shm-size=512M \
       --cap-drop=ALL \
       --cap-add CAP_SYS_NICE \
       --cap-add CAP_SETGID \
       --cap-add CAP_SETUID \
       --cap-add CAP_SYS_CHROOT \
       --cap-add CAP_SYS_PTRACE \
       --cap-add CAP_NET_ADMIN \
       --cap-add CAP_SYS_ADMIN \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       -e LANG \
       --userns=keep-id \
       -e WAYLAND_DISPLAY \
       -e XDG_RUNTIME_DIR="/tmp/$USER/run" \
       -e STEAM_USE_MANGOAPP=1 \
       -e SRT_URLOPEN_PREFER_STEAM=1 \
       -e STEAM_ENABLE_VOLUME_HANDLER=1 \
       -e vblank_mode \
       --userns=keep-id \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       -v /dev/dri:/dev/dri \
       -v /dev/snd:/dev/snd \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME" bash -c "pipewire-pule & gamescope-exec --adaptive-sync --hdr-enabled --rt -S integer -e -W \"$WIDTH\" -H \"$HEIGHT\" -- /usr/games/steam"

#       --cap-add=CAP_FOWNER \
#       --cap-add=CAP_CHOWN \
#       --cap-add=CAP_DAC_OVERRIDE \
#       --cap-add=CAP_DAC_READ_SEARCH \
#       --cap-add=CAP_SETUID \
#       --cap-add=CAP_SETGID \
#       --security-opt=no-new-privileges \
