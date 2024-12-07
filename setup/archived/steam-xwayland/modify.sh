#!/bin/bash

set -e

if [ ! -e ./image.info ]; then
    echo "You first need to run setup.sh to create an image."
    exit 1
fi

WRAP_NAME="wrap-$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && basename "$(pwd -P)" )-img"

echo "Modifying wrap image from $(cat image.info) -> ${WRAP_NAME}"

podman rm -fi wrap-upgrade-tmp 

if [ -n "$1" ]; then
  podman run \
       --user=root \
       --name=wrap-upgrade-tmp \
       --hostname="$(cat image.info)" \
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
       "$(cat image.info)" "$@"
else
  podman run \
       -it \
       --user=root \
       --name=wrap-upgrade-tmp \
       --hostname="$(cat image.info)" \
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
       "$(cat image.info)" /bin/bash
fi
  
podman commit wrap-upgrade-tmp "$WRAP_NAME"
echo "$WRAP_NAME" > image.info

podman rm -fi wrap-upgrade-tmp
