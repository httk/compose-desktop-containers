This container provides discord.

All screen sharing applications are tricky to get to work in
containers (or for that matter, even running on the desktop itself)

The default launcher (exec-discord.sh) connects to your the xwayland
(or x11) server running outside of the container and needs
xwaylandvideobridge installed for screen sharing to work well.
(remember to re-login after having installed it, so it gets
autostarted).

First install discord with:

  ./install.sh

Then run it with:

  ./exec-discord.sh

There are a few other launchers in the directory to can be tested and
modified to get other setups working, but they are mostly not
documented here.

Rerun ./install.sh when there is an update to discord.

Note: discord supports wayland windows and decorations, but seems to
still need access to an x11 server to start up (possibly for screen
sharing).  In my testing, discord crashed when trying to screen share
via xwaylandvideobridge together with running the application in
Wayland.
