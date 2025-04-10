#!/bin/bash

set -e

if [ ! -e ./image.info ]; then
    echo "You first need to run setup.sh to create an image."
    exit 1
fi

WRAP_NAME="wrap-$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && basename "$(pwd -P)" )-img"
IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat image.info)"
NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

echo "Modifying wrap image from $(cat image.info) -> ${WRAP_NAME}"

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
       "$IMAGE_NAME" bash -c "apt update && apt dist-upgrade -y"
fi
  
podman commit wrap-upgrade-tmp --change "CMD=/bin/bash" --change "USER=$USER" "$WRAP_NAME"
podman rm -fi wrap-upgrade-tmp
podman image prune -f

echo "$WRAP_NAME" > image.info
