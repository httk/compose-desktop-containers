This container is (or is based on) generic-x11
This container sets up a direct link to the x11 server running on your desktop.

Important: allowing x11 program direct access to the x11 server outside the container
is not a good security barrier. At the very these programs can access all windows, run keyloggers, etc.
There may be X11 extensions available that can allow programs running in the container to escape.
(And even if not intentional, the many X11 extensions provide a large surface for attack.)

A better option is implemented in generic-xwayland, which runs an isolated xwayland server in
the container that connects to a wayland server running on your desktop.

Good tests:
  vblank_mode=0 ./exec-nodri.sh glxgears
  vblank_mode=0 ./exec.sh glxgears

To open a terminal inside the container use:
  ./exec-nodri.sh xterm

