#!/bin/bash

set -e

# If the container is already runs, don't restart (ssh server already running)
ID="$(podman ps -q -f "name=sshserver_container_runtime")"
if [ -n "$ID" ]; then
    echo "App already running; won't restart"
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

podman run --rm \
       --net=host \
       --name "sshserver_container_runtime" \
       -w "/home/$USER" \
       --hostname="$NAME" \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       --userns=keep-id \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME" bash -c "exec sshd -D -h ~/.ssh/hostkeys/ssh_host_ed25519_key -p 12121 -o 'UsePAM no' -o 'ListenAddress 127.0.0.1'" &

PODMAN="$?"
trap 'kill $PODMAN' SIGINT

echo "Server has started. Log in with:"
echo "  ssh-add files/ssh_client_ed25519_key"
echo "  ssh -p 12121 localhost"

wait
