#!/bin/bash

set -e

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)
IMAGE_NAME="$(cat "$IMAGE_DIR/image.info")"

if ! podman image exists "$IMAGE_NAME"; then
    echo "You first need to create the image: $IMAGE_NAME"
    exit 1
fi

if [ -e files/seopowersuite.tar.gz ]; then
    EXISTFLAG="-z files/seopowersuite.tar.gz"
else
    EXISTFLAG=""
fi
curl -L -o files/seopowersuite.tar.gz $EXISTFLAG "https://www.link-assistant.com/download/linux/seopowersuite.tar.gz"

FIXES=""

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    FIXES="$FIXES --read-only=false"
    echo "Warning: read-only turned off due to old version of crun."
fi

NAME=${IMAGE_NAME%-img}
NAME=${NAME#wrap-}

LATESTURL="$(curl -L 'https://flashforge.com/blogs/download-software/software' | sed -n 's|^.*"\(https://[^/]\+/FlashPrint_[0-9.]\+/flashprint5_[0-9.]\+_amd64.deb\)".*$|\1|p')"
LATESTFILENAME="${LATESTURL##*/}"

if [ -z "$LATESTFILENAME" ]; then
    echo "Failed to determine latest slack version."
    exit 1
fi

mkdir -p files opt
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
	-v "$IMAGE_DIR/opt:/opt:rw" \
	-v "$IMAGE_DIR/home:/home/$USER:rw" \
        $FIXES \
	"$IMAGE_NAME" bash -c "rm -rf /opt/seopowersuite /opt/link-assistantcom && mkdir /opt/seopowersuite && cd /opt/seopowersuite && tar -zxvf /files/seopowersuite.tar.gz && cd seopowersuite; fakeroot ./install.sh"



#bash -c "rm -rf /opt/seopowersuite /opt/link-assistantcom && mkdir /opt/seopowersuite && cd /opt/seopowersuite && tar -zxvf /files/seopowersuite.tar.gz && mkdir -p /opt/link-assistantcom/websiteauditor/ && ln -s /opt/seopowersuite/seopowersuite/distr/specific/websiteauditor/bin /opt/link-assistantcom/websiteauditor/bin && ln -s ../commons/runtime /opt/link-assistantcom/websiteauditor/runtime && ln -s ../commons/resources /opt/link-assistantcom/websiteauditor/resources && ln -s /opt/seopowersuite/seopowersuite/distr/commons /opt/link-assistantcom/commons"

#mkdir -p ~/.local/share/icons/hicolor/64x64/apps ~/.local/share/applications
#cat "$IMAGE_DIR/tools/seopowersuite.desktop" | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-seopowersuite.sh\" --url %U|;" > ~/.local/share/applications/seopowersuite_container.desktop
#cp "$IMAGE_DIR/home/seopowersuite/seopowersuite/usr/share/icons/hicolor/64x64/apps/flashforge5.png" ~/.local/share/icons/hicolor/64x64/apps/flashforge5.png
#update-desktop-database ~/.local/share/applications/
#gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
