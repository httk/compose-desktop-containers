#!/bin/bash

set -e

mkdir -p opt home
rm -rf opt/gamescope

cat > Containerfile <<EOF
FROM ubuntu:24.04
USER root
RUN apt-get update && apt-get -y dist-upgrade
RUN apt-get -y install gcc-mingw-w64 gcc-multilib libasound2-dev libcups2-dev libdbus-1-dev libfontconfig-dev libfreetype-dev libgl-dev libgnutls28-dev libgphoto2-dev libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev libosmesa6-dev libpcap-dev libpulse-dev libsane-dev libsdl2-dev libudev-dev libunwind-dev libusb-1.0-0-dev libvulkan-dev libx11-dev libxcomposite-dev libxcursor-dev libxext-dev libxfixes-dev libxi-dev libxrandr-dev libxrender-dev ocl-icd-opencl-dev samba-dev git flex bison && apt-get autoremove -y && rm -rf /var/tmp/* && rm -rf /tmp/*
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

podman build -t build-wine .

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)

podman run --rm \
       --user="$USER" \
       --hostname=build-wine \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       --userns=keep-id \
       -v "$IMAGE_DIR/opt:/opt:rw" \
       -v "$IMAGE_DIR/home:/home/${USER}:rw" \
       $FIXES \
       build-wine bash -c "rm -rf cd ~/build/wine && mkdir -p ~/build/wine ~/install/wine /opt/rum /opt/wines && cd ~/build/wine && git clone https://gitlab.com/xkero/rum && cd rum && git checkout 394d75c4 && cp -rp * /opt/rum/. && cd .. && git clone https://gitlab.winehq.org/ElementalWarrior/wine.git ElementalWarrior-wine && cd ElementalWarrior-wine && git switch affinity-photo2-wine8.14 && git checkout c12ed146 && mkdir winewow64-build/ wine-install/ && cd winewow64-build/ && ../configure --prefix=/opt/wines/ElementalWarrior-8.14 --enable-archs=i386,x86_64 && make --jobs 4 && make install && ln -s wine /opt/wines/ElementalWarrior-8.14/bin/wine64"

podman rmi build-wine
podman image prune -f

echo "Wine built; result available in opt"
