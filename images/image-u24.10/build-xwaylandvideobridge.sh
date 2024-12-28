#!/bin/bash

set -e

cat > Containerfile <<EOF
FROM ubuntu:24.10
USER root
RUN apt-get update && apt-get -y dist-upgrade
RUN apt-get install -y git cmake build-essential extra-cmake-modules qt6-base-dev libkpipewire-dev pkg-config kwin-dev libkf6notifications-dev libkf6config-dev libkf6guiaddons-dev libkf6configwidgets-dev libkf6windowsystem-dev libkf6coreaddons-dev gettext libx11-xcb-dev libxcb-*-dev pkg-config libkf6crash-dev kinit-dev libkf6globalaccel-dev libkf6kio-dev kwin-dev libkf6statusnotifieritem-dev
EOF

# We need to handle the user part differently depnding on if it overlaps the default 1000 user or not.
if [ "$UID" == "1000" ]; then

    cat >> Containerfile <<EOF
RUN usermod -l "$USER" ubuntu && groupmod -n "$USER" ubuntu && usermod -d "/home/$USER" -m "$USER" && usermod -c "$FULLNAME" "$USER" && mkdir /tmp/$USER && chown "$USER:$USER" "/tmp/$USER" && chmod 0700 "/tmp/$USER" && mkdir "/tmp/$USER/run" && chown "$USER:$USER" "/tmp/$USER/run" && chmod 0700 "/tmp/$USER/run"
USER $USER
EOF

else

    cat >> Containerfile <<EOF
RUN groupadd -r -g "$UID" "$USER" && useradd -m -u "$UID" -g "$UID" -c "$FULLNAME" "$USER" && mkdir /tmp/$USER && chown "$USER:$USER" "/tmp/$USER" && chmod 0700 "/tmp/$USER" && mkdir "/tmp/$USER/run" && chown "$USER:$USER" "/tmp/$USER/run" && chmod 0700 "/tmp/$USER/run"
USER $USER
EOF

fi

podman build -t build-xwaylandvideobridge .

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)

mkdir -p "$IMAGE_DIR/outputs/etc/xdg"
podman run --rm \
       --user="$USER" \
       --hostname=build-xwaylandvideobridge \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       --userns=keep-id \
       -v "$IMAGE_DIR/outputs:/home/$USER:rw" \
       -v "$IMAGE_DIR/outputs/etc/xdg:/etc/xdg:rw" \
       $FIXES \
       build-xwaylandvideobridge bash -c "rm -rf ~/build/xwaylanvideobridge ~/install/xwaylandvideobridge && mkdir -p ~/build/xwaylanvideobridge/build ~/install/xwaylandvideobridge/usr/local && cd ~/build/xwaylanvideobridge && git clone https://invent.kde.org/system/xwaylandvideobridge.git src && cd src && git checkout v0.4.0 && git submodule update --init && cd ~/build/xwaylanvideobridge/build && cmake -DCMAKE_BUILD_TYPE=Release -S ../src -B . -DBUILD_WITH_QT6=true && cmake --build . && cmake --install . --prefix ~/install/xwaylandvideobridge/usr/local"

#git checkout v0.4.0 7d806511

podman rmi build-xwaylandvideobridge
podman image prune -f
rm -rf outputs/build

(cd outputs/install/xwaylandvideobridge; rm -f ../../../files/xwaylandvideobridge.tgz; tar -zcvf ../../../files/xwaylandvideobridge.tgz .)

echo "Xwaylandvideobridge built; result available in outputs/install/xwaylandvideobridge"
