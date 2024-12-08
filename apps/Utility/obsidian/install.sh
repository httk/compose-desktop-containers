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

LATESTURL="$(curl -L 'https://obsidian.md/download' | sed -n 's|^.*"\(https://.*/obsidian_[0-9.]\+_amd64\.deb\)".*$|\1|p')"
LATESTFILENAME="${LATESTURL##*/}"

if [ -z "$LATESTFILENAME" ]; then
    echo "Failed to determine latest slack version."
    exit 1
fi

mkdir -p files home
if [ ! -e "files/$LATESTFILENAME" ]; then
    curl -L -o "files/$LATESTFILENAME" "$LATESTURL"
fi

podman run --rm \
       -w "/home/$USER" \
       --hostname="$NAME" \
       --user="$USER" \
       --cap-drop=ALL \
       --read-only \
       --read-only-tmpfs \
       --systemd=false \
       --security-opt=no-new-privileges \
       -e LANG \
       -e GNUPGHOME=/tmp/root/.gnupg \
	--userns=keep-id \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
	-v "$IMAGE_DIR/files/":/files/ \
	-e DISPLAY \
	-v "$XAUTHORITY:$XAUTHORITY" \
	-e XAUTHORITY \
	-e vblank_mode \
	--userns=keep-id \
	-v "$IMAGE_DIR/home:/home/$USER:rw" \
        $FIXES \
	"$IMAGE_NAME" bash -c "rm -rf ~/obsidian && mkdir ~/obsidian && cd ~/obsidian &&  dpkg-deb -x \"/files/$LATESTFILENAME\" obsidian && mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/256x256/apps/ && cp obsidian/usr/share/applications/obsidian.desktop ~/.local/share/applications/obsidian.desktop && sed -i 's%^Exec=.*%Exec=/home/$USER/obsidian/obsidian/opt/Obsidian/%' ~/.local/share/applications/obsidian.desktop && cp obsidian/usr/share/icons/hicolor/256x256/apps/obsidian.png ~/.local/share/icons/hicolor/256x256/apps/. && update-desktop-database ~/.local/share/applications/"

mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
cat "$IMAGE_DIR/tools/obsidian.desktop" | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-obsidian.sh\" %U|;" > ~/.local/share/applications/obsidian_container.desktop
cp "$IMAGE_DIR/home/obsidian/obsidian/usr/share/icons/hicolor/256x256/apps/obsidian.png" ~/.local/share/icons/hicolor/256x256/apps/obsidian.png
update-desktop-database ~/.local/share/applications/
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
