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

LATESTURL="$(curl -L 'https://slack.com/downloads/instructions/linux?ddl=1&build=deb' | sed -n 's|^.*src="\(https://downloads.slack-edge.com/desktop-releases/linux/x64/[^/]*/[^/]*-amd64.deb\).*$|\1|p')"
LATESTFILENAME="${LATESTURL##*/}"

if [ -z "$LATESTFILENAME" ]; then
    echo "Failed to determine latest slack version."
    exit 1
fi

mkdir -p files
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
	"$IMAGE_NAME" bash -c "rm -rf ~/slack && mkdir ~/slack && cd ~/slack &&  dpkg-deb -x \"/files/$LATESTFILENAME\" slack && mkdir -p ~/.local/share/applications && cp slack/usr/share/applications/slack.desktop ~/.local/share/applications/slack.desktop && sed -i 's%/usr/bin/slack%/home/$USER/slack/slack/usr/bin/slack%' ~/.local/share/applications/slack.desktop && update-desktop-database ~/.local/share/applications/"

mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
cat "$IMAGE_DIR/tools/slack.desktop" | sed "s|^Exec=.*$|Exec=\"${IMAGE_DIR}/exec-slack.sh\" %U|;" > ~/.local/share/applications/slack_container.desktop
cp "$IMAGE_DIR/home/slack/slack/usr/share/pixmaps/slack.png"  ~/.local/share/icons/hicolor/256x256/apps/slack.png
update-desktop-database ~/.local/share/applications/
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor

# "mkdir -m 0700 -p /tmp/root/.gnupg && cd /tmp && gpg --import /root/files/Slack.pubkey.pem && gpg --verify /root/files/slack_amd64.deb && apt-get install -y /root/files/slack_amd64.deb"
