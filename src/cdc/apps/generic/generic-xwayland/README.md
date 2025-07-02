This container is (or is based on) generic-xwayland.
This container sets up an xwayland instance inside the container and connects it to the wayland display server running on your desktop.

Since it does not seem to work well with multiple xwayland instances using --rootless, rootfull mode is used, embedding an openbox window manager
set to maximize all windows. This appear to work reasonably well.

There are separate exec-dri.sh and exec-nodri.sh scripts that provide or blocks access to the direct rendering interface, which may be an attack surface.

Good test:
  ./exec.sh glxgears

To open a terminal inside the container use:
  ./exec.sh xterm
  ./exec.sh foot

You can also open a console session in your own terminal:
  ./interactive.sh
