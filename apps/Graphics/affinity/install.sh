#!/bin/bash

set -e

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat "$IMAGE_DIR/image.info")"

if ! podman image exists "$IMAGE_NAME"; then
    echo "You first need to create the image: $IMAGE_NAME"
    exit 1
fi

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

mkdir -p files
NBR_FILES=$(ls -d files/affinity-designer-msi-*.exe files/affinity-publisher-msi-*.exe files/affinity-photo-msi-*.exe files/WinMetadata | wc -l)

if [ "$NBR_FILES" -lt "4" ]; then
    echo "Missing installation files: you must download the Windows installers and place in file/, and the WinMetadata folder from a Windows system"
    exit 1
fi

OPT_LINKS=""
for OPT_LINK in opt/*; do
    LINK=$(readlink "$OPT_LINK")
    OPT_LINKS="$OPT_LINKS -v ${IMAGE_DIR}/opt/${LINK}:/${OPT_LINK}:ro"
done
echo opt/*
echo "OPT LINKS: $OPT_LINKS"


podman run --rm \
       -w "/home/$USER" \
       --name "affinity_container_runtime" \
       --hostname="$NAME" \
       --user="$USER" \
       --shm-size=1G \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       -e XDG_RUNTIME_DIR \
       -e XDG_DATA_DIRS \
       -e BROSER="falkon" \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       --device /dev/dri \
       --userns=keep-id \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -e DISPLAY \
       -v $XAUTHORITY:$XAUTHORITY \
       -e XAUTHORITY \
       $FIXES \
       $OPT_LINKS \
       -v "$IMAGE_DIR/files:/files:ro" \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       "$IMAGE_NAME" bash -c "export PATH=\$PATH:/opt/rum && rum ElementalWarrior-8.14 $HOME/.wineAffinity wineboot --init && rum ElementalWarrior-8.14 \"$HOME/.wineAffinity\" winetricks --unattended dotnet48 corefonts && rum ElementalWarrior-8.14 $HOME/.wineAffinity wine winecfg -v win11 && cp --recursive /files/WinMetadata $HOME/.wineAffinity/drive_c/windows/system32/WinMetadata && rum ElementalWarrior-8.14 $HOME/.wineAffinity wine /files/affinity-designer-msi-*.exe"

#bash -c "rm -rf ~/spotify && mkdir ~/spotify && cd ~/spotify &&  dpkg-deb -x \"/files/$LATESTFILENAME\" spotify && mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/256x256/apps/ && cp spotify/usr/share/spotify/spotify.desktop ~/.local/share/applications/spotify.desktop && sed -i 's%^Exec=.*%Exec=/home/$USER/spotify/spotify/usr/share/spotify/spotify%' ~/.local/share/applications/spotify.desktop && cp spotify/usr/share/spotify/icons/spotify-linux-256.png ~/.local/share/icons/hicolor/256x256/apps/. && gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor && update-desktop-database ~/.local/share/applications/"

#mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
#cat "$IMAGE_DIR/tools/spotify.desktop" | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-spotify.sh\" %U|;" > ~/.local/share/applications/spotify_container.desktop
#cp "$IMAGE_DIR/home/spotify/spotify/usr/share/spotify/icons/spotify-linux-256.png" ~/.local/share/icons/hicolor/256x256/apps/spotify-client.png
#update-desktop-database ~/.local/share/applications/
#gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
