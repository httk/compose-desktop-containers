This container is a zoom container.

Zoom is tricky to get to work in a sane way with screen sharing and without crashing.
Hence, there are two different installs (normal and alternative) and several different
execution scripts to try different configurations to see what works. Try them and see
if there is an option that runs Zoom, with screen sharing, without crashing.

    HINT: try activating "optimize for video sharing" in the screen sharing settings
    if Zoom crashes during screen sharing.

The default way to run Zoom is to first (once before first start) run `install.sh`, and
then start zoom with `exec-zoom.sh` runs soom with a direct linkt to the x11 server
running on your desktop (which likely is xwayland). This is the setup that seems to have
the most success with Zoom. Hovever, it also is quite weak from a security barrier view,
as it means Zoom has access to all clients running on your xwayland and the x11 protocol
was not designed to be a proper security barrier.

An alternative way is to install the 'deb' version of Zoom in the wrap image. This gives
better library integration with the host system which can fix some crashed, but it also
means other things running in the wrap image gets access to the zoom binary (but not your
personal configuration), which is an attack vector. To try this version, first run
`install-alt-mod-img-deb.sh` and then start zoom with `exec-zoom-alt-deb.sh`.

A third option is to try to run Zoom "properly over wayland". To do this, first run `./install.sh`,
and then `./exec-zoom-wayland.sh`. For me, however, this leads to a crash after just
interacting with the main zoom window for a while. Perhaps we need for Zoom's Wayland support
to further mature. (Zoom's default is to interact with xwayland even when running on Wayland.)
