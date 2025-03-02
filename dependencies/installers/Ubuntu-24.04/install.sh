#!/bin/bash

sudo apt-get install -y \
     crun podman podman-compose curl wmctrl xdotool python3-tk python3-gi python3-gst-1.0 gstreamer1.0-pipewire gir1.2-appindicator3-0.1 yq

# Create a udev rule to place camera devices inside /dev/cameras instead to allow easy hot-pluggable sharing of all camera video devices
sudo tee /etc/udev/rules.d/99-cdc.rules <<EOF
ACTION=="add", SUBSYSTEM=="cpu", RUN+="/bin/mkdir -p -m 0755 /dev/video"
ACTION=="add", SUBSYSTEM=="video4linux", RUN+="/bin/mkdir -p -m 0755 /dev/video"
KERNEL=="video*", SUBSYSTEM=="video4linux", ACTION=="add", RUN+="/bin/mv /dev/%k /dev/video/%k"
KERNEL=="video*", SUBSYSTEM=="video4linux", ACTION=="add", RUN+="/bin/ln -s /dev/video/%k /dev/%k"
KERNEL=="video*", SUBSYSTEM=="video4linux", ACTION=="remove", RUN+="/bin/rm -f /dev/video/%k /dev/%k"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger
