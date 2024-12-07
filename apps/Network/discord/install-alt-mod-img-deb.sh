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

podman rm -fi wrap-upgrade-tmp 

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
       -v "$IMAGE_DIR/files/":/files/ \
       $FIXES \
       "$IMAGE_NAME" bash -c "apt-get install -y /files/discord-0.0.72.deb"

podman commit wrap-upgrade-tmp --change "CMD=/bin/bash" --change "USER=$USER" "$IMAGE_NAME"
podman rm -fi wrap-upgrade-tmp
podman image prune -f
