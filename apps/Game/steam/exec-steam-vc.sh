#!/bin/bash

set -e

if [ ! -e ./image.info ]; then
    echo "You first need to run setup.sh to create an image."
    exit 1
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat image.info)"
NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

WIDTH=$(xdpyinfo | awk '/dimensions/ {print $2}' | awk -Fx '{print int(0.85*$1)}')
HEIGHT=$(xdpyinfo | awk '/dimensions/ {print $2}' | awk -Fx '{print int(0.85*$2)}')

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
       -e WAYLAND_DISPLAY \
       -e XDG_RUNTIME_DIR="/tmp/$USER" \
       -e SRT_URLOPEN_PREFER_STEAM=1 \
       -e STEAM_ENABLE_VOLUME_HANDLER=1 \
       -e ENABLE_GAMESCOPE_WSI=0 \
       -e DXVK_HDR=0 \
       -e vblank_mode \
       --userns=keep-id \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/$WAYLAND_DISPLAY:ro" \
       -v /dev/dri:/dev/dri \
       --device=/dev/snd:/dev/snd \
       -v /tmp/.X11-unix:/opt/.X11-unix:rw \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       "$IMAGE_NAME" gamescope-exec --adaptive-sync --rt -S integer -e -W "$WIDTH" -H "$HEIGHT" -- /usr/games/steam "$@"

#       -v hide:/opt/.X11-unix/X0:ro \
#       -v hide:/opt/.X11-unix/X1:ro \


#       -v "$IMAGE_DIR/home/.X11-unix-steam:/tmp/.X11-unix:rw" \
#	-e PRESSURE_VESSEL_FILESYSTEMS_RO=/tmp/.X11-unix/X2 \
#       --cap-add=CAP_FOWNER \
#       --cap-add=CAP_CHOWN \
#       --cap-add=CAP_DAC_OVERRIDE \
#       --cap-add=CAP_DAC_READ_SEARCH \
#       --cap-add=CAP_SETUID \
#       --cap-add=CAP_SETGID \
#       --security-opt=no-new-privileges \

#       -e STEAM_USE_MANGOAPP=1 \
