# Compose-Desktop-Containers (CDC)

Helpers to handle launcher and desktop integration for containers using docker/podman compose declaration files.

Containerized apps -- here implemented via podman non-root containers -- provide a security layer to reduce the risks when running less trusted software.
The CDC helpers enable easy creation of both command line and XDG desktop launchers for installed applications.

The compose format is extended with an `x-launchers` stanza that specify a set of launchers. Launching an app via these launchers is a convinient way to
execute a `podman-compose up` (setting up the container), a `podman-compose exec` (running the software), and a `podman-compose down` (to close down the container).
Furthermore, a number of maintenance tasks are provided that allows `download`, `build`, and `install` steps for those apps where this makes sense,
allowing a complete containerized build recepie to distributed as a single compose yaml file.

## Quickstart for users

1. The absolutely easiest way to install this app is via `pipx`:
   ```
   pipx install https://github.com/httk/compose-desktop-containers
   ```
   (In contrast to `pip`, `pipx` installs pypi-packaged software into your home directory in a way where it does not get tied to a specific venv.
   This is the right choice for "tools" that you want to have access to across your interactions with different venvs.)

2. CDC needs some software and configuration of your system. Run the following command:
   ```
   cdc install
   ```
   This will type out a set of instructions to execute on your system to install necessary system dependencies and to build the CDC standard container image.

3. Create a directory for holding your installed containerized apps, e.g., `~/Containers/cdc`:
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
   cdc setup Networking/discord.yaml
   ```

6. You should now find `Discord` in your desktop system launcher. Or, you can run it in the terminal:
   ```
   cd discord
   ./discord
   ```

7. If you for some reason want to force a re-install of discord, you can do so via the maintenance tasks under `setup/`:
   ```
   ./setup/reinstall
   ```

## Exchanging files between the container, host system, and other containers

The command `cdc setup` set up a standard `override.yaml` file that is used for customization of the app's `compose.yaml` file.
The standard override file usually comes with a directory binding between the container system and the host for a shared subdirectory under `~/Documents/containers`.
Edit the `override.yaml` file to configure this to your liking.

Other files inside the user's home directory in the container `/home/<username>/` are mapped to the subdirectory `home` in the apps directory.

## Update one app

Update if needed:
```
cd <app directory>
cdc update-if-needed
```
Force an update:
```
./setup/update
```

## Other types of updates

For security reasons, you should want to update the CDC container image frequently.
You can do this by
```
cdc image-update
```

However, there is a convinience helper to just "update everything":
```
cd ~/Containers
cdc update-all
```

## Update the application definition files

When running `cdc setup`, the application definition files provided by the repository are not copied, they are created as symbolic links.
Hence, simply running `pipx upgrade https://github.com/httk/compose-desktop-containers` will automatically upgrade the application definition files for apps installed this way.

If you have obtained a compose yaml file from some other source, simply replace `compose.yaml` in the apps directory with the new one.

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
  Icons are installed using the normal name of the application (e.g., `blender.png`) to allow for themeing to work as expected.
  (But it is also difficult to imagine that leaving application icons here would cause any trouble.)

There is one final thing: CDC keeps some configuration related to requests from apps to install system packages into the standard container.
To purge these, check, and possibly remove, the directories:

* `~/.config/cdc/image-*/requested/<application>`

## Installation for developers

Those who want to work with the cdc source code are recommened to:

Clone the repository somewhere in your home directory:
```
cd ~/Containers
git clone https://github.com/httk/compose-desktop-containers cdc --recurse-submodules
cd cdc
```

Create a virtualenv in which `cdc` can be pip-installed "editable":
```
make venv
source .venv/bin/activate
pip install -e .
```

Now, anytime you activate this venv, you will have access to the version of cdc represented by the source code in that repo.

If you are surfficiently happy with a development version to want to have access to it even without activating the venv, you do:
```
pipx install --force .
```
(The force make sure to replace an existing copy if there is one). However, this will install *a copy* of your development version of CDC as a tool in your home directory. Changes you make from this point will not be reflected in that version (you need to activate the venv) until you re-run the `pipx` command.


## Design details

CDC extends the compose system by:

- CDC defines specific extensions to the compose yaml format via 'x-*' keys that enable declaring features relevant for desktop applications:

  * The top-level `x-application` key defines a label, a name, a `README.md`, and default contents for an `override.yaml` and a `.env` to help create configurable containers.
  * A top-level `x-launchers` key under which the app declare its various launchers with all meta-data that goes along (e.g., `.desktop` files, icons, etc.)

- A convinient way to "install" compose applications.

  * When running `cdc setup` on a defintion yaml file, a directory is created for the application containing `compose.yaml`, `override.yaml`, `.env`, symlinks for the launchable application entry points, and a `home` directory to isolate filesystem access for the application when run.

  * Apart from the symlink launchers (e.g. `./blender`), `cdc-setup` also makes applications available in the host desktop system via `.desktop` files in `~/.local/share/applications`. 

- Via the `x-launchers` key, CDC declares an interface for specific maintence tasks. The main ones are:

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
  It is implemented as: first brining the service container `up`. Then executing the launcher's script with `exec`. And finally the container is usually shut down with `down`.
  Users do not usually need to execute this manually, as it is automated via the launcher symlinks.
  However, the manual hidden command is: `cdc launch <launcher>`.

- A `cdc-entrypoint` program is provided which "does the right thing" when using compose containers to run interactive software. On brining `up` a container, it executes the `command`
  (possibly as root, if that is what `user` is set to) and then stalls, waiting for the container to be shut down again.

Using this extended compose framework, "applications" can be distributed as single yaml files.

### Further notes on design choices

A common model for containerized applications is that an application is delivered as its own 'image', along with all its dependencies.
This seems very attractive at first, but comes with limitations:

* If the container actually contains all the data itself: the application binary, and binaries for all dependencies, they will be very big.
* Installing applications this way leads to a lot of duplication.
* Upgrading and otherwise maintaining the dependencies is tricky.

In practice, most container systems have evolved into not cleanly implementing this approach, and instead started to add dependencies between containers, which also leads to complications.

CDC uses the exteme opposite of this model. All software runs in containers instantiated from one and the same image.
If system software is missing in this container, the image is updated to include it.
This design model has both benefits and drawbacks.

*Benefits:*

* It simplifies keeping the container system software up to date independently from application software updates, so that, e.g., apps don't rely on outdated, possibly vulnerable, versions of security-sensitive system software (e.g., libssl, gnutls).

* Existing application definition files are set up to be able to install new versions directly as they get released. There is no need to wait for a new release of an updated container.

* It makes it fairly simple to keep a resonable scaling of storage use from many installed applications.

*Drawbacks:*

* Future changes of system software, or applications, may unexpectedly break the installation/update process.
  This means: there is a risk that `cdc setup <app>` fails because of an inompability between the version the yaml file was created for, and the latest version of the software.
  This should not be possible with "curated images" tailored to each software release.

* All apps must be made to run on the specific image(s) provided. Right now, the standard is: Ubuntu LTS 24.04.
  (We may expand this to images for all maintained LTS releases.)

* Apps will be able to access to all system software (e.g., libraries) installed in the image for use by other apps, which arguably reduces the security barrier somewhat.
  (On the other hand, malicious software could just embedd (or download) the same functionality.)

* Changes (e.g., updates) to the master container image may affect all containerized software (e.g., in the worst case, a library update could break previous working software; this should, however, be rare).

