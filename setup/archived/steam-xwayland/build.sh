#!/bin/bash

cat > Containerfile <<EOF
FROM wrap-base-img
USER root
RUN apt-get update && apt-get -y dist-upgrade
RUN apt-get -y install xterm mesa-utils libx11-data x11-utils foot xwayland openbox && mkdir -p /tmp/.X11-unix && chmod a+rwxt /tmp/.X11-unix
RUN apt-get -y install --no-install-recommends pulseaudio alsa-utils libasound2-plugins
RUN apt-get -y install --no-install-recommends dbus dbus-x11 bubblewrap && chmod u+s /usr/bin/bwrap && dpkg --add-architecture i386 && apt-get update && apt-get install -y steam-installer
COPY ./xwayland-exec /usr/bin/xwayland-exec
RUN chmod +x /usr/bin/xwayland-exec
USER "$USER"
EOF

#RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y libc6:amd64 libc6:i386 libegl1:amd64 libegl1:i386 libgbm1:amd64 libgbm1:i386 libgl1-mesa-dri:amd64 libgl1-mesa-dri:i386 libgl1:amd64 libgl1:i386 steam-libs-amd64:amd64 steam-libs-i386:i386 steam-installer

podman build -t wrap-steam-xwayland-img .

#./modify.sh su "$USER" -c "xwayland-exec /usr/games/steam"

#./modify.sh bash -c "wget -O ~/steam.deb http://media.steampowered.com/client/installer/steam.deb && apt -y install ~/steam.deb && rm ~/steam.deb"

echo "wrap-steam-xwayland-img" > image.info

echo "Image built. Note, first execution may be very slow to start."
echo
echo "Run with:"
echo "  ./exec-steam.sh"
echo ""
