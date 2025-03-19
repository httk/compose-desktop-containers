# Compose-Desktop-Containers (CDC)

*Note: for anyone finding this: this software is currently in an early work-in-progress state. Once the design reaches a bit more maturity, we will track proper releases.*

Scripts and tools to describe containerized desktop applications using the industry standard docker/podman-compose yaml files.
Containerized apps, here implemented using podman non-root containers, provide a security layer to reduce the risks of running less trusted software.
The tools create both command line and desktop launchers for installed applications.

## Quickstart

Clone the repository and initialize submodule dependecies in, for example, `~/Containers`:
```
git clone --recurse-submodules 'https://github.com/httk/compose-desktop-containers.git' ~/Containers 
```

Install dependencies (replace `<your host system>` with the name of the OS you are installing the containers on):
```
cd dependencies/installers/<your host system>
./install.sh
cd ../../..
```

Build the container image:
```
cd images/image-u24
./build-gamescope.sh
./build.sh
cd ../..
```
This first builds some dependencies, which is helper software we need for the image, and then builds the `cdc-u24` image.

### Install and run an app
```
cd ~/Containers
../tools/cdc-setup apps/Networking/discord.yaml discord
```
Now try to start discord from your system launcher, or run `./discord` in the application directory.

### Exchanging files between the container, host system, and other containers

The `cdc-setup` script set up a standard `override.yaml` file.
Commonly the standard override file sets up a mapping between the host and container system for an appropriate directory under `~/Documents/containers`.
Edit the `override.yaml` file to configure this to your liking.

Other files inside `/home/<username>/` are mapped to a subdirectory `home` in the container directory.

### Update an app
```
cd <app directory>
~/Containers/tools/cdc-update
```
Now try to start discord from your system launcher.

### Update the application definition files to the latest ones in this repository
```
cd ~/Containers
git pull
```
(Installed compose.yaml files are symbolic links to the ones under `apps`, so they get updated automatically.
If you do not want this feature, you can remove the symbolic link and copy the file instead.)

### Troubleshooting

The first thing to try if you have trouble with a specific app is to just re-initialize it:
```
cd <app directory>
~/Containers/tools/cdc-resetup
```
This keeps your files in the `home` subdirectory, but redownloads, rebuilds, and reinstalls the app.

The second thing to try is to remove the whole state of the app, i.e., the `home` subdirectory, and then run `cdc-resetup`.
IMPORTANT: make sure to move out any files you want to keep from there first.

The third thing to try is to rebuild the podman image. 
The deepest reset you can do is to run `podman system reset`, which completely purges all internal podman configuration (including any other podman images you may have, outside of CDC...)
After that, re-do the "Build the image" step above, and then try to start your app again.

### Uninstalling applications

Before removing an application you likely want to look into the application `home` subdirectory and copy any files you want to preserve.

After that, the installed application and its state can be purged by simply removing the directory where the application was installed.

There is currently no script for removing the `.desktop` files and icons from the host system, but they are unlikely to cause any issues if just left.
If you anyway want to make sure to clean out an installation as much as possible, check out the following directories in your home directory on the host system:

* `~/.local/share/applications`: remove the relevant `<application>_cdc.desktop` files.
* `~/.local/share/<application name>_cdc`: this directory is in rare occasions created to store application icons that have to be in the same location on the host system and inside the container.
  (I'd consider that a bug, but sometimes seems unavoidable.)
* `~/.local/share/icons/hicolor`: in the subdirectories below here, application icons are installed.
  Icons are installed using the normal name of the application (e.g., `blender.png`) to allow for themeing to work as expected.
  (But it is also difficult to imagine that leaving application icons here would cause any trouble.)


## Details

cdc extends the compose system by providing:

- A clear interace to compose files that assigns specific meaning to the following services:

  * `download`: download the files needed to build/install the application.
  * `download-clean`: clean up downloads so that next invokation of download will redownload the necessary files.
  * `build`: conduct non-networked build steps necessary between downloading and installation.
  * `build-clean`: clean up previous builds so that next invokation of `build` rebuilds the app.
  * `install`: installs the application.
  * `install-clean`: clean up previous installations so that next invokation of `install` reinstalls the app.
  * `update-check`: returns exit code 0 if the app is at its latest version (or this cannot be determined).
  * `update`: attempt to update the app.

- A definition of some specific 'x-*' keys in the compose.yaml configuration that enable features relevant for desktop applications:

  * The top-level `x-application` key defines a `README.md`, and default contents for an `override.yaml` and a `.env` to help create configurable containers.
  * Under specific services one can define an `x-launcher` key to mark them as launchable as application entry points, with their own `.desktop` files, icons, etc.
  * The `x-application` section allows definition of an app-global `.desktop file`, icons, and dependencies on packages that are needed in the container image.
  * The `x-launcher` key may furthermore list services, e.g., `video` that are set up when launching to give access to the video devices on the host system, etc.
  * The `x-app-init` allows for initialization steps executed as root, before `command` is executed as the user.

- A new "launch" mode for running services with somewhat different semantics than "run" and "start" activated via the command `cdc-launch <service name>`

  * Executes the commands under the `command` key as if the `run` mode was invoked, without starting a compose service.

- Helper scripts to setup and interface in various ways with the app services.

  * When running `cdc-setup` on a defintion yaml file, a directory is created for the application containing `compose.yaml`, `override.yaml`, `.env`, symlinks for the launchable application entry points, and a `home` directory to isolate filesystem access for the application when run.

  * Apart from the symlink launchers (e.g. `./blender`), `cdc-setup` also makes applications available in the host desktop system via `.desktop` files in `~/.local/share/applications`. 

Using this extended compose framework, "applications" are distributed as single yaml files on the extended compose.yaml format.
These yaml files only contain instructions for downloading and installing the application.

## Some notes on the design choices

The usual design model of containerized applications in, e.g., flatpack, snap, etc., is that applications are delivered as separate self-contained containers that can be installed and run independently.
In CDC, the model is rather that there is a single "parallel" container system (i.e., ideally one image) that lives inside your host system.
This parallel system can be independently upgraded, be extended with new dependency libraries, etc.
We then run a range of installed applications inside this parallel containerized system. This shift in design model has both benefits and drawbacks.

Benefits:

* Allows keeping the container system software up to date independently from application software updates, so that, e.g., apps don't rely on outdated, possibly vulnerable, version of security-sensitive system software (e.g., libssl, gnutls).

* Existing application definition files will (try to) install new versions directly as they get released, instead of waiting for a new release of an updated container.

* Arguably, the model allows better scaling of storage use to many installed applications since they are meant to share a single image (or in the worst case, a few).

Drawbacks:

* Future changes of applications may unexpectedly break the update process (which shouldn't happen in other container formats where updates are done via tested new definition files).

* All apps must be made to run on the image(s) provided. Right now, the standard is: Ubuntu LTS 24.04; going forward the idea will likely be to handle images for all maintained LTS releases.

* Apps will be able to access to system software (e.g., libraries) installed in the image for use by other apps, which arguably reduces the security barrier somewhat.
  (On the other hand, malicious software could just embedd (or download) the same functionality.)

* Changes (e.g., updates) to the master container image may affect all containerized software (e.g., in the worst case, a library update could break previous working software; this should, however, be rare).

## Design notes

The top level directory contains the subdirectories:

* `images`: used to build the system podman image used for the containers.
* `apps`: a hierarchy of subdirectories for yaml files defining a number of applications.
* `tools`: scripts used to install, configure, and launch applications.

The `apps` contains one subdirectory for each catogory in the XDG desktop specification meant to be the primary categorization of the app, below which there are `app.yaml` files for the provided applications.
