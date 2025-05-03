#!/bin/bash

sudo apt-get install -y crun podman curl wmctrl xdotool python3-tk python3-gi python3-gst-1.0 gstreamer1.0-pipewire gir1.2-appindicator3-0.1 yq mesa-utils

# Create a udev rule to duplicate the video device nodes inside /dev/video to allow hot-plugging of cameras into containers
# If you skip this, everything will work except you cannot hot-plug video devices to already running software inside containers
sudo tee /etc/udev/rules.d/99-cdc.rules <<EOF
KERNEL=="video*", SUBSYSTEM=="video4linux", ACTION=="add", RUN+="/bin/bash -c '/bin/mkdir -p -m 0755 /dev/video; MAJOR=\$\$(stat -c %%t /dev/%k | xargs printf \"%%d\"); MINOR=\$\$(stat -c %%T /dev/%k | xargs printf \"%%d\"); mknod /dev/video/%k c \$\$MAJOR \$\$MINOR; chown root:video /dev/video/%k; chmod 0660 /dev/video/%k'"
KERNEL=="video*", SUBSYSTEM=="video4linux", ACTION=="remove", RUN+="/bin/rm -f /dev/video/%k"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger

if grep -q 'direct rendering: Yes' <<< "$GLXINFO" && grep -q 'OpenGL vendor string: NVIDIA' <<< "$GLXINFO"; then
    if [ "$XDG_SESSION_TYPE" == "wayland" ]; then
        echo "WARNING: xwayland on NVIDIA driver accelerated desktops currently do not work well: you will get flicker from applications that are routed to wayland via xwayland (not just containerized applications...)."
        echo "There are workarounds (xorg-xwayland-explicit-sync), but the only simple full fix seems to be to switch your desktop to x11, or to change to run desktop graphics on your iGPU."
    fi
fi

if command -v nvidia-smi 2>/dev/null; then
    echo "For GPU feature support, you need to install the NVIDIA Container Toolkit:"
    echo 'curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |     sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list'
    echo 'sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml'
fi
