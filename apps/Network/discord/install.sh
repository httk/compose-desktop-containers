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
if [ -e files/discord.tar.gz ]; then
    EXISTFLAG="-z files/discord.tar.gz"
else
    EXISTFLAG=""
fi
curl -L -o files/discord.tar.gz $EXISTFLAG "https://discordapp.com/api/download?platform=linux&format=tar.gz"

#wget -O files/discord.tar.gz "https://discordapp.com/api/download?platform=linux&format=tar.gz"

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
	"$IMAGE_NAME" bash -c "rm -rf ~/discord && mkdir ~/discord && cd ~/discord && tar -xvf /files/discord.tar.gz && mkdir -p ~/.local/share/applications && cp Discord/discord.desktop ~/.local/share/applications/discord.desktop && sed -i 's%/usr/share/discord/Discord%/home/$USER/discord/Discord/Discord%'  ~/.local/share/applications/discord.desktop && update-desktop-database ~/.local/share/applications/"

mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
#cat "$IMAGE_DIR/tools/discord.desktop" | sed "s%^Exec=.*\$%Exec=${IMAGE_DIR}/../setup/tools/switch-or-exec.sh discord \"${IMAGE_DIR}/exec-discord.sh\"%" > ~/.local/share/applications/discord_container.desktop
cat "$IMAGE_DIR/tools/discord.desktop" | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-discord.sh\" --url %U|;" > ~/.local/share/applications/discord_container.desktop
cp "$IMAGE_DIR/home/discord/Discord/discord.png" ~/.local/share/icons/hicolor/256x256/apps/discord.png
update-desktop-database ~/.local/share/applications/
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor

# "mkdir -m 0700 -p /tmp/root/.gnupg && cd /tmp && gpg --import /root/files/Discord.pubkey.pem && gpg --verify /root/files/discord_amd64.deb && apt-get install -y /root/files/discord_amd64.deb"
