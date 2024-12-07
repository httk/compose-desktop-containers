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

# Workaround: this seems to work best for fullscreen for some reason
# WIDTH=1280
# HEIGHT=720

#
#home/gamescope --adaptive-sync --rt -S integer -- podman run --rm \
    #home/gamescope --adaptive-sync --rt -S integer -W "$WIDTH" -H "$HEIGHT" -- podman run --rm \
#    home/gamescope --adaptive-sync --rt -S integer --xwayland-count 2 -e -- podman run --rm \
../images/fat-u24/outputs/install/usr/local/bin/gamescope --adaptive-sync --rt -S integer -e -- podman run --rm \
     --user="$USER" \
       --hostname="$(cat image.info)" \
       --shm-size=512M \
       --cap-drop=ALL \
       --cap-add CAP_SYS_NICE \
       --cap-add CAP_SETGID \
       --cap-add CAP_SETUID \
       --cap-add CAP_SYS_CHROOT \
       --cap-add CAP_SYS_PTRACE \
       --cap-add CAP_NET_ADMIN \
       --cap-add CAP_SYS_ADMIN \
       --cap-add SYS_TTY_CONFIG \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       -e LANG \
       -e STEAM_GAMESCOPE_NIS_SUPPORTED \
       -e SRT_URLOPEN_PREFER_STEAM \
       -e STEAM_MULTIPLE_XWAYLANDS \
       -e STEAM_GAMESCOPE_TEARING_SUPPORTED \
       -e STEAM_GAMESCOPE_HAS_TEARING_SUPPORT \
       -e STEAM_GAMESCOPE_VRR_SUPPORTED \
       -e STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND \
       -e STEAM_MANGOAPP_HORIZONTAL_SUPPORTED \
       -e STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT \
       -e STEAM_GAMESCOPE_HDR_SUPPORTED \
       -e STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER \
       -e STEAM_MANGOAPP_PRESETS_SUPPORTED \
       -e STEAM_USE_MANGOAPP \
       -e XWAYLAND_FORCE_ENABLE_EXTRA_MODES \
       -e SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS \
       -e GAMESCOPE_NV12_COLORSPACE \
       -e MANGOHUD_CONFIGFILE \
       -e GAMESCOPE_LIMITER_FILE \
       -e DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1 \
       -e XDG_RUNTIME_DIR="/tmp/$USER/run" \
       -e STEAM_ENABLE_VOLUME_HANDLER=1 \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e DISPLAY \
       --userns=keep-id \
       -v /dev/dri:/dev/dri \
       -v /dev/snd:/dev/snd \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       "$IMAGE_NAME" bash -c "pipewire-pulse & /usr/games/steam" "$@"

#       -e DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/$USER/run/bus" \
#       -v "$XDG_RUNTIME_DIR/bus:/tmp/$USER/run/bus" \

# /usr/games/steam "$@"

#       -e STEAM_USE_MANGOAPP=1 \
#       -e STEAM_MULTIPLE_XWAYLANDS=1 \
#--xwayland-count 2

#       --cap-add=CAP_FOWNER \
#       --cap-add=CAP_CHOWN \
#       --cap-add=CAP_DAC_OVERRIDE \
#       --cap-add=CAP_DAC_READ_SEARCH \
#       --cap-add=CAP_SETUID \
#       --cap-add=CAP_SETGID \
#       --security-opt=no-new-privileges \
