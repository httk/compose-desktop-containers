This is the 'steam' container, which is based on generic-gamescope
It allows a few different ways of integrating Steam, podman containers, and gamescope.

This container sets up a special sharing of a gamescope X11 display on display number 42.
It is meant to be used with exec-steam-vc. Don't start anything important
on that display, as it will be visible inside the container.

Fullsceen mode does generally not work reliably with GNOME.
It you want to run steam and games inside GNOME on your desktop in fullscreen,
go into the GNOME keyboard configuration and enable a shortcut for fullscreen.
Start steam with ./exec-steam-fullscreen.sh, and if steam anyway opens up with window decorations,
use the shortcut to maximize the window to get rid of them.

For the recommanded way of running this container with games on a virtual console, you need
gamescope on the host. Normally, it would just be "sudo apt install gamescope", however,
for some reason it was not packaged for Ubuntu 24.04. Hence, the 'base' setup of these
containers builds gamescope. However, for it to work, you need to install the library
dependencies. This should be sufficient:

sudo apt install libsdl2-2.0-0 libseat1 libxres1 libinput10

## Recommended way: Steam on desktop, games on virtual consoles:

1. Access one of your virtual consoles (say, ctrl + alt + f5).
2. Login, and start 'gamescope-vc-daemon.sh'
3. Go back to your main login (usually ctrl + alt + f2).
4. Start steam with 'exec-steam-vc.sh'.
5. Configure steam games that you want to run in fullscreen on the virtual console with 'gamescope-on-vc <args> -- %command%'. Where <args> are the gamescope arguments you want to use, e.g., you can set the launch command to: "gamescope-on-vc -W 1920 -H 1080 --adaptive-sync -- %command%"
6. For any games you rather run in the steam window on your normal desktop, leave the launch command empty.

## Alternative way 1: everything runs on desktop (does not give access to adaptive sync, ability to adjust hadware resolution)

1. Start Steam with exec-steam.sh

## Alternative way 2: everything runs on virtual console

1. Access one of your virtual consoles (say, ctrl + alt + f5).
2. Login, and start 'exec-steam-vc-only.sh'

The steam window runs on virtual console, and when you start games, they will run there as well.
