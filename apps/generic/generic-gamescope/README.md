This container is (or is based on) generic-gamescope.
This container runs program in the X11 microcompositor gamescope
(primarily targeting games, but works for other X11 software)
which then displays graphics on the wayland server running on your desktop.

Good tests:
  ./exec-dri.sh glxgears

To open a terminal inside the container:
  ./exec.sh foot
  ./exec.sh xterm

You can also open a console session in your own terminal:
  ./interactive.sh

Some helpful debug variables that can be set:
  export MESA_DEBUG=1"
  export EGL_LOG_LEVEL=debug"
  export LIBGL_DEBUG=verbose"
  export WAYLAND_DEBUG=1"
