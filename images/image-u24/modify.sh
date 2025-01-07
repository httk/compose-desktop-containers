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

echo "Modifying wrap image from $(cat image.info) -> wrap-u24-img"

podman rm -fi wrap-upgrade-tmp

if [ -n "$1" ]; then
  podman run \
       -w "/" \
       --hostname="$NAME" \
       --user=root \
       --name=wrap-upgrade-tmp \
       --cap-drop=ALL \
       --cap-add=CAP_FOWNER \
       --cap-add=CAP_CHOWN \
       --cap-add=CAP_DAC_OVERRIDE \
       --cap-add=CAP_DAC_READ_SEARCH \
       --cap-add=CAP_SETUID \
       --cap-add=CAP_SETGID \
       --read-only=false \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       --userns=keep-id \
       --volume="${IMAGE_DIR}/files:/files:ro" \
       -e LANG \
       "$IMAGE_NAME" "$@"
else
  podman run \
       -it \
       -w "/" \
       --hostname="$NAME" \
       --user=root \
       --name=wrap-upgrade-tmp \
       --cap-drop=ALL \
       --cap-add=CAP_FOWNER \
       --cap-add=CAP_CHOWN \
       --cap-add=CAP_DAC_OVERRIDE \
       --cap-add=CAP_DAC_READ_SEARCH \
       --cap-add=CAP_SETUID \
       --cap-add=CAP_SETGID \
       --read-only=false \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       --userns=keep-id \
       -e LANG \
       --volume="${IMAGE_DIR}/files:/files:ro" \
       "$IMAGE_NAME" /bin/bash
fi

podman commit wrap-upgrade-tmp --change "CMD=/bin/bash" --change "USER=$USER" desktop-container-u24
podman tag desktop-container-u24 desktop-container-default
podman rm -fi wrap-upgrade-tmp
podman image prune -f
