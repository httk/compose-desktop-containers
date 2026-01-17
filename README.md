# Compose-Desktop-Containers (CDC)

Helpers for managing containerized applications for desktop and command-line use based on docker/podman compose declaration files.

Containerized apps -- here implemented via podman non-root containers -- is a convenient way to deliver apps that run in a controlled environment. They also provide a security barrier to reduce the risks of running less trusted software.

CDC extends the docker/podman compose yaml format with `x-application` and `x-launchers` stanzas to declare "launchers", which are various ways to run the app (including things like icons for desktop integration).
Furthermore, the launchers can include maintenance tasks such as `download`, `build`, `install`, and `update`, giving an interface for users to interface with these maintenance tasks and allowing the distribution of apps as build recipes. (Where the user does not even need to *trust* the build recipe, which may be important.)

## Quickstart for users

(If you want to install CDC in a way where you can edit its source code, see [Installation for developers](#installation-for-developers))

1. On Ubuntu if you do not already have `pipx`, first install it:
   ```
   sudo apt install pipx
   ```
   (Or, if you have `uv`, you can replace `pipx` by `uv tool` below, but `uv` cannot currently be installed via `apt`.)

   Install CDC by:
   ```
   pipx install 'git+https://github.com/httk/compose-desktop-containers.git'
   ```
   (In contrast to `pip`, `pipx` is meant for application software to be installed in your home directory without getting tied to a specific virtual Python environment.
   This is the right choice for general "tools" that you want to always have access to.)

2. CDC needs some software and configuration of your system. Run the following command:
   ```
   cdc first-run-host-setup
   ```
   This types out a set of instructions to execute on your host system to install necessary system dependencies.
   The final set of these instructions should be to build the CDC standard container image:
   ```
   cdc image-create
   ```

3. Create a directory for holding your installed containerized apps, e.g., `~/Containers`:
   ```
   mkdir ~/Containers
   cd ~/Containers
   ```

4. List the apps provided alongside CDC:
   ```
   cdc apps
   ```
   (You can also just obtain a CDC-compatible yaml file from somewhere else)

5. Install one of the apps
   ```
   cdc setup Networking/discord
   ```
   Note how it asks you to update the container image, hence also do:
   ```
   cdc image-update
   ```

6. You should now be able to find `Discord` in your desktop system launcher menu. Or, to run it in the terminal:
   ```
   cd discord
   ./discord
   ```

7. If you for some reason want to force a re-install of discord, you can do so via the maintenance tasks under `setup/`:
   ```
   ./setup/reinstall
   ```

## Exchanging working files between the container, host system, and other containers

One common challenge with containerized software is how to exchange files with the host system and between containerized applications.
CDC intends for you to do this by shared directories residing under `~/Documents/containers/<application-specific subdirs>`.
However, this is fully customizable.

When you install an app with `cdc setup`, it creates the default `override.yaml` that is used for customization of the app's `compose.yaml` file.
This standard `override.yaml` usually comes with a pre-filled line for the directory binding under `~/Documents/containers`.
Just edit the `override.yaml` file to configure this to your liking.

All other files inside the user's home directory inside the container `/home/<username>/` are mapped to the subdirectory `home` in the apps directory on the host.
You are discouraged from using this directory to store any valuable user-created files. 
However, the apps own configuration data will be stored here, usually within a directory at `~/.config/<app name>` or `~\.<app name>`).
Sometimes such configuration data can be valuable.

## Update one app

To check if an app can be updated, and if so, run the update maintenance task:
```
cd <app directory>
cdc update-if-needed
```
To instead force an update:
```
./setup/update
```

## Other types of updates

You should regularly update the CDC container image:
```
cdc image-update
```

However, there is a convenience helper `update-all` to just "update everything".
You run this at the top of a directory tree of installed apps. It will first update the CDC container image, and then crawl this directory and run `update-if-needed` on all found apps.
```
cd ~/Containers
cdc update-all
```

## Update the application definition files

When running `cdc setup`, the application definition files provided by the repository are not copied, they are symbolic links back to CDC:s internal directory for app definition files.
Hence, when you run `pipx upgrade https://github.com/httk/compose-desktop-containers`, it will automatically upgrade all your application definition files for apps installed this way.

The symbolic links has as a consequence that it is not safe to edit the file `compose.yaml` points at.
(It is an internal CDC file that will be replaced if you update CDC).
Your configuration should primarily be done via `override.yaml`.
In cases where that is not enough, make a non-symbolic-link copy of `compose.yaml` first:
```
mv compose.yaml compose-orig.yaml
cp compose-orig.yaml compose.yaml
```
Now you can edit `compose.yaml` as needed.

If you have obtained a CDC compose yaml file from another source, simply replace `compose.yaml` in the apps directory with the new one.

## Troubleshooting

The very first thing to try if you have trouble with a specific app is to troubleshoot by checking the files in the `home` subdirectory either directly
(it is a subdirectory to the app directory) or by entering the apps file system with the `interactive` launcher many of the apps provide.
(This is similar to what you would typically try with an app installed directly on your host system.)

The second thing to try is to completely re-initialize it:
```
cd <app directory>
cdc resetup
```
This leaves the `home` subdirectory intact, but redownloads, rebuilds, and reinstalls the app.

A third thing to try is to remove the whole state of the app, i.e., the `home` subdirectory, and then run `cdc-resetup`.

**IMPORTANT:** You are not *meant* to keep any important files in the app-specific `home` directory. They are meant to go, e.g., under `~/Document/containers` on the host system via the directory linking configured in `override.yaml`. However, since this directory is available to write in when running the app, you may stil have ended up with something you like to keep there. *Make sure to copy/move out any files you want to keep from there before removing this directory!*

The third thing to try is to rebuild the CDC podman image. You can do so with `cdc image-create`.

The final troubleshooting step is to completely purge your podman config. **IMPORTANT:** this will including erasing any other podman images you may have, outside of CDC!
To do this: run `podman system reset`. After that, re-do `cdc image-create`, and then try to start your app again.

## Uninstalling applications

Before removing an application you likely want to look into the application `home` subdirectory and copy any files you want to preserve.

After that, the installed application and its state can be purged by simply removing the directory where the application was installed.

There is currently no script for removing the `.desktop` files and icons from the host system, but they are unlikely to cause any issues if just left.
If you anyway want to make sure to clean out an installation as much as possible, check out the following directories in your home directory on the host system:

* `~/.local/share/applications`: remove the relevant `<application>_cdc.desktop` files.
* `~/.local/share/<application name>_cdc`: this directory is in rare occasions created to store application icons that have to be in the same location on the host system and inside the container.
  (I'd consider that a bug, but sometimes seems unavoidable.)
* `~/.local/share/icons/hicolor`: in the subdirectories below here, application icons are installed.
  Icons are installed using the normal name of the application (e.g., `blender.png`) to allow for theming to work as expected.
  (But it is also difficult to imagine that leaving application icons here would cause any trouble.)

There is one final thing: CDC keeps some configuration related to requests from apps to install system packages into the standard container.
To purge these, check, and possibly remove, the directories:

* `~/.config/cdc/image-*/requested/<application>`

## Installation on servers for services

1. Setup the podman-compose systemd service:
   ```
   sudo podman-compose systemd -a create-unit
   ```

2. Create an ssh key to be able to ssh into service user accounts:
   ```
   ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_services
   ```

3. Setup a services user accout

   Set up another user account for running containerized services
   ```
   sudo useradd -m -s /bin/bash services
   sudo loginctl enable-linger services
   sudo install -d -m 700 ~services/.ssh
   printf 'from=\"127.0.0.1,::1\" %s\n' "$(cat $HOME/.ssh/id_services.pub)" | sudo tee -a ~services/.ssh/authorized_keys
   sudo chmod 600 ~services/.ssh/authorized_keys
   sudo chown -R services:services ~services/.ssh
   # sudo restorecon -R /home/services # <- may be needed on some systems
   ```

4. Now we can swap over to the service user account with ssh agent-forwarding (important if we want to auth to github):
   ```
   ssh -A -i ~/.ssh/id_services services@localhost
   ```

5. Installation as `services` user.

   Followed the installation instructions for users or developers first; it is suggested that you use the subdirectory `Services` in your home directory to hold the containers.

6. Now do:
   
   ```
   cdc services
   ```

   To list installable servies.

8. Install a service (we will use plex as an example):

   ```
   cdc install AudioVideo/plex
   ```

9. Activate it for systemd (technically you don't *have* to do this, if you prefer, you can run a service manually).

   ```
   podman-compose --project-name plex systemd -a register
   systemctl --user enable --now podman-compose@plex
   ```

   Check the status when running as the `services` user:
   ```
   systemctl --user status podman-compose@plex
   ```

   But, now you can also `exit` out of the `services` user and go back to your regular user, where you can check the status as:
   ```
   sudo systemctl --user -M services@ status podman-compose@plex
   ```
   And turn off/on the running service as:
   ```
   sudo systemctl --user -M services@ down podman-compose@plex
   sudo systemctl --user -M services@ up podman-compose@plex
   ```
   And disable/re-enable the autostart at boot as:
   ```
   systemctl --user disable --now podman-compose@plex
   systemctl --user enable --now podman-compose@plex
   ```

## Update

To update system packages and rebuild the latest release:
```
podman-compose --podman-args='--target build_stage' build --no-cache
```


## Installation for developers

Users who want to be able to work with the CDC source code are recommend to install it as follows.

Make sure you have `pipx` or `uv` available.
On Ubuntu you can install `pipx` by:
```
sudo apt install pipx
```
(If you prefer `uv` you can just replace `pipx` -> `uv` in the instructions below).

Clone the source code repository somewhere in your home directory:
```
mkdir ~/Tools
cd Tools
git clone https://github.com/httk/compose-desktop-containers cdc --recurse-submodules
```

Install CDC using the editable (`-e`) flag:
```
cd cdc
pipx install -e .
```

If you change the dependencies, you may need to force-reinstall it using pipx:
```
pipx install --force -e .
```
(The `--force` directs `pipx` to replace any existing copy).

Note: if you prefer to work in a normal virtualenv and skip `pipx`, you can do


## Design decisions and details

CDC extends the compose system by:

- CDC defines specific extensions to the compose yaml format via 'x-*' keys that enable declaring features relevant for desktop applications:

  * The top-level `x-application` key defines a label, a name, a `README.md`, and default contents for an `override.yaml` and a `.env` to help create configurable containers.
  * A top-level `x-launchers` key under which the app declare its various launchers with all meta-data that goes along (e.g., `.desktop` files, icons, etc.)
  * An `x-features` key under the service declarations for a simplified interface to things like video devices, dbus forwarding, gpu_compute access, that otherwise are tricky to configure manually.

- CDC provides a way for apps to be installed via build recipes or binary distributions that run somewhat safely inside the container.

  * When running `cdc setup` on a definition yaml file, a directory is created for the application containing `compose.yaml`, `override.yaml`, `.env`, symlinks for the launchable application entry points, and a `home` directory to isolate filesystem access for the application when run.

  * Apart from the symlink launchers (e.g. `./blender`), `cdc-setup` also makes applications available in the host desktop system via `.desktop` files in `~/.local/share/applications`. 

- Via the `x-launchers` key, CDC declares an interface for specific maintenance tasks. The main ones are:

  * `download`: download any files needed to build/install the application.
  * `build`: conduct the (usually non-networked) build steps necessary between downloading and installation.
  * `install`: install the application.
  * `update`: attempt to update the app.
  * `update-check`: returns exit code 1 if the app thinks running `update` would be meaningful. (Some apps cannot update, in which case they will always exit with code 0).

  The app is allowed (but not required) to skip the step if it has already been done.
  To force the operation in these cases, use the "re-" versions:

  * `redownload`
  * `rebuild`
  * `reinstall`

- CDC invents a new compose "launch mode" for running services with somewhat different semantics than the standard ones: "up", "run", and "exec".
  It is implemented as: first bringing the service container `up`. Then executing the launcher's script with `exec`. And finally the container is usually shut down with `down`.
  Users do not usually need to execute this manually, as it is automated via the launcher symlinks.
  However, the manual hidden command is: `cdc launch <launcher>`.

- A `cdc-entrypoint` program is provided which "does the right thing" when using compose containers to run interactive software. On bringing `up` a container, it executes the `command`
  (possibly as root, if that is what `user` is set to) and then stalls, waiting for the container to be shut down again.

Using this extended compose framework, "applications" can be distributed as single yaml files.

### Further notes on design choices

Containerized applications, at least when they started to appear, were often presented according to the idea of freestanding
images, where the app itself was provided along with all of its dependencies, often as binaries.
To deploy apps as completely separate isolated environments may seem attractive at first, but comes with limitations:

* If the container actually contains all the data itself: the application binary, and binaries for all dependencies, they will be large.
* Installing several applications this way leads to a lot of duplication.
* Upgrading and otherwise maintaining the dependencies becomes tricky.

In practice, most container systems have now evolved into a less clean implementation of this idea; and there are frequently systems for deduplication and ways to express dependencies between containers.

CDC uses the extreme opposite of the 'one-app-per-image' model. All software is meant to run in a single image (or, possibly as we move forward, a couple).
If system software that an app depends on is missing in this container, the image needs to be updated to include it.
This design has both benefits and drawbacks.

*Benefits:*

* It simplifies keeping the container system software up to date independently from application software updates, so that, e.g., apps don't rely on outdated, possibly vulnerable, versions of security-sensitive system software (e.g., libssl, gnutls).

* Existing application definition can contain general instructions for installing, or updating to, the latest version of an app directly as it gets released.
  The app version is not tied to image or container versions.

* A reasonable scaling of storage use for many installed applications follows naturally from the design.
  No system software needs to be duplicated.

*Drawbacks:*

* Future changes of system software, or applications, may unexpectedly break the installation/update process.
  This means: there is a risk that `cdc setup <app>` fails because of an inompability between the version the yaml file was created for, and the latest version of the software.
  This should not be possible with "curated images" tailored to each software release.

* All apps must be made to run on the specific image(s) provided. Right now, the standard is: Ubuntu LTS 24.04.
  (We may expand this to images for all maintained LTS releases.)

* Apps will be able to access to all system software (e.g., libraries) installed in the image for use by other apps, which arguably reduces the security barrier somewhat.
  (On the other hand, malicious software could just embedd (or download) the same functionality.)

* Changes (e.g., updates) to the master container image may affect all containerized software (e.g., in the worst case, a library update could break previous working software; this should, however, be rare).

* Those composing app definition files will have to make a decision between indicating dependencies on system packages (which is a little less convenient for end users, since they need to update their image to accommodate these), or whether to install the dependency software specifically for the app.


