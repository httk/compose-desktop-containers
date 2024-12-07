#!/bin/bash

set -e

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

if [ -e files/zoom_x86_64.tar.xz ]; then
    EXISTFLAG="-z files/zoom_x86_64.tar.xz"
else
    EXISTFLAG=""
fi
curl -L -o files/zoom_x86_64.tar.xz $EXISTFLAG "https://zoom.us/client/latest/zoom_x86_64.tar.xz"
if [ -e files/zoom_amd64.deb ]; then
    EXISTFLAG="-z files/zoom_amd64.deb"
else
    EXISTFLAG=""
fi
curl -L -o files/zoom_amd64.deb $EXISTFLAG "https://zoom.us/client/latest/zoom_amd64.deb"

#wget -N -O files/zoom_x86_64.tar.xz "https://zoom.us/client/latest/zoom_x86_64.tar.xz"
#wget -N -O files/zoom_amd64.deb "https://zoom.us/client/latest/zoom_amd64.deb"

(
rm -rf files/tmp
mkdir files/tmp
cd files/tmp
ar x ../zoom_amd64.deb
tar -xvf data.tar.xz
cp ./usr/share/pixmaps/Zoom.png ../.
)
rm -rf files/tmp

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
	"$IMAGE_NAME" bash -c "rm -rf ~/zoom && mkdir ~/zoom && cd ~/zoom && tar -xvf /files/zoom_x86_64.tar.xz && mkdir -p ~/.local/share/applications && echo -e '[Desktop Entry]\nName=ZoomLauncher\nComment=Zoom Video Conference\nExec=/home/${USER}/zoom/zoom/ZoomLauncher %U\nTerminal=false\nType=Application\nEncoding=UTF-8\nCategories=Network;Application;\nMimeType=x-scheme-handler/zoommtg;x-scheme-handler/zoomus;x-scheme-handler/tel;x-scheme-handler/callto;x-scheme-handler/zoomphonecall;\nX-KDE-Protocols=zoommtg;zoomus;tel;callto;zoomphonecall\nName[en_US]=ZoomLauncher' > ~/.local/share/applications/ZoomLauncher.desktop && update-desktop-database ~/.local/share/applications/"

mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
#cat "$IMAGE_DIR/tools/zoom.desktop" | sed "s|^Exec=.*\$|Exec=${IMAGE_DIR}/../setup/tools/switch-or-exec.sh zoom \"${IMAGE_DIR}/exec-zoom.sh\" %U |" > ~/.local/share/applications/zoom_container.desktop
cat "$IMAGE_DIR/tools/zoom.desktop" | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-zoom.sh\" %U|" > ~/.local/share/applications/zoom_container.desktop
cp "$IMAGE_DIR/files/Zoom.png" ~/.local/share/icons/hicolor/256x256/apps/Zoom.png
update-desktop-database ~/.local/share/applications/
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor

# "mkdir -m 0700 -p /tmp/root/.gnupg && cd /tmp && gpg --import /root/files/Zoom.pubkey.pem && gpg --verify /root/files/zoom_amd64.deb && apt-get install -y /root/files/zoom_amd64.deb"
