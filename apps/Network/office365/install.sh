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

echo "***********************************************************"
echo "Running chrome: please navigate to the microsoft 365 apps"
echo "by using the 9-dots app navigator icon, and then in the"
echo "browser navigator-field click the icon to install Teams and"
echo "OneDrive"
echo "***********************************************************"

podman run --rm \
       --user="$USER" \
       --shm-size=1G \
       --hostname="$NAME" \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --cap-drop=ALL \
       --cap-add CAP_SYS_CHROOT \
       --security-opt=no-new-privileges \
       -e LANG \
       -e WAYLAND_DISPLAY \
       -e DISPLAY \
       -v /tmp/.X11-unix:/tmp/.X11-unix \
       -v $XAUTHORITY:$XAUTHORITY \
       -e XAUTHORITY \
       -e XDG_RUNTIME_DIR="/tmp/$USER/run" \
       --userns=keep-id \
       -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$USER/run/$WAYLAND_DISPLAY:ro" \
       -v "$XDG_RUNTIME_DIR/pipewire-0:/tmp/$USER/run/pipewire-0" \
       -v /dev/dri:/dev/dri \
       -v "$IMAGE_DIR/home:/home/$USER:rw" \
       $FIXES \
       "$IMAGE_NAME" bash -c "google-chrome 'https://www.microsoft365.com/'"

# "$IMAGE_NAME" bash -c "google-chrome --ozone-platform=wayland 'https://www.microsoft365.com/'"

mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications

DESKTOP_FILE="$(find "$IMAGE_DIR/home/.local/share/applications/" -name "*.desktop" | xargs grep -l '^Name=Microsoft Teams$')"
if [ -n "$DESKTOP_FILE" ]; then
    CHROMIUM_APP_ID="${DESKTOP_FILE%*-Default.desktop}"
    CHROMIUM_APP_ID="${CHROMIUM_APP_ID##*/chrome-}"
    echo "Chromium app ID: $CHROMIUM_APP_ID"
    cat "$IMAGE_DIR/tools/msteams.desktop" | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-msteams.sh\"|;" > ~/.local/share/applications/msteams_container.desktop
    cp "$IMAGE_DIR/home/.local/share/icons/hicolor/256x256/apps/chrome-${CHROMIUM_APP_ID}-Default.png" ~/.local/share/icons/hicolor/256x256/apps/msteams.png
    update-desktop-database ~/.local/share/applications/
    gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
else
    echo "Installed PWA for MS Teams not found; skipping installation."
fi

DESKTOP_FILE="$(find "$IMAGE_DIR/home/.local/share/applications/" -name "*.desktop" | xargs grep -l '^Name=Microsoft OneDrive$')"
if [ -n "$DESKTOP_FILE" ]; then
    CHROMIUM_APP_ID="${DESKTOP_FILE%*-Default.desktop}"
    CHROMIUM_APP_ID="${CHROMIUM_APP_ID##*/chrome-}"
    echo "Chromium app ID: $CHROMIUM_APP_ID"
    cat "$IMAGE_DIR/tools/onedrive.desktop" | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-onedrive.sh\"|;" > ~/.local/share/applications/onedrive_container.desktop
    cp "$IMAGE_DIR/home/.local/share/icons/hicolor/256x256/apps/chrome-${CHROMIUM_APP_ID}-Default.png" ~/.local/share/icons/hicolor/256x256/apps/onedrive.png
    update-desktop-database ~/.local/share/applications/
    gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
else
    echo "Installed PWA for OneDrive not found; skipping installation."
fi

    
# "mkdir -m 0700 -p /tmp/root/.gnupg && cd /tmp && gpg --import /root/files/Discord.pubkey.pem && gpg --verify /root/files/discord_amd64.deb && apt-get install -y /root/files/discord_amd64.deb"
