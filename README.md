# httk Desktop Containers

This is a way to run less trused desktop applications via a security layer provided via a non-root podman container.

In difference to e.g., flatpack, snap, etc., only a single container image is used (but run in multiple isolated instances).
There are benefits and drawbacks to this design, versus the more common setup with one image per app.

Benefits:

* Makes it feasible to keep the system software in the container up to date so that, e.g., apps don't rely on outdated, possibly vulnerable, version of security-sensitive system software (e.g., libssl).

* Less demands on storage (only one image) and memory (same system libraries for all running apps).

Drawbacks:

* All apps have access to system software (e.g., libraries) installed in the image for other apps, which arguably reduces the security barrier somewhat. On the other hand, malicious software can just embedd (or download) the same functionality.

* Changes (e.g., updates) to the master container image may affect all containerized software (e.g., in the worst case, break them all)

## Design notes

The top level directory contains the subdirectories:

* `setup`: used to build the system image and set up the container system.
* `apps`: a hierarchy of subdirectories for pre-configured apps.
* `generic`: templates used to set up the configuration for apps.

For the app subdirectories under `apps`, there is a clear separation between the containerized "system" (provided in the container image which they cannot alter) and the specific application software and its state, which is stored in subdirectories of the application -- usually in the "home" subdirectory.

To install an app, enter the subdirectory and issue './install.sh'. This sets up a dot-desktop file under your `~/.local` to make the software executable directly from your desktop system as "<software name> (container)". For larger control, investigate the scripts named `exec-<something>.sh`.

Given that the system image is stateless and detached from the apps, it is at any time safe to clean out your podman configuration and rebuild it.
Hence, you can at any time run `podman system reset` to completely purge your podman configuration, and then follow the instructions again to rebuild the system container. (Note: be aware that `podman system reset` deletes *all* podman images and containers, not just the ones associated with these scripts.)

## Quickstart: build the system image

Install prerequistes:
```
cd setup/host-installers
ls
cd <relevant host>
./install.sh
cd ../../..
```

Build the main container:
```
cd setup/image-u24
./build-gamescope.sh
./build.sh
cd ../..
```
This first builds gamescope, which is helper software we need for the image, and then builds the `desktop-container-default` image.

### Test the container
```
cd generic/generic-console
./exec.sh echo "hello world"
cd ../..
```
(Note: the first execution of a newly built container can take quite long; subsequent excutions should be much faster).

### Install an app
``
ln -s apps/Network/VideoConference/discord .
cd discord
./install.sh
``
Now try to start discord from your system launcher.
