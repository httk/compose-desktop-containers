This container sets up a direct link to the wayland server running on your desktop.
It will only work with programs that natively support the wayland protocol.

Good tests:
  ./exec.sh weston-simple-egl
  ./exec-nodri.sh weston-simple-egl

To open a terminal inside the container:
  ./exec.sh foot
  ./exec.sh weston-terminal

You can also open a console session in your own terminal:
  ./interactive.sh

Some helpful debug variables that can be set:
  export MESA_DEBUG=1"
  export EGL_LOG_LEVEL=debug"
  export LIBGL_DEBUG=verbose"
  export WAYLAND_DEBUG=1"
