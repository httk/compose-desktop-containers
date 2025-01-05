#!/bin/bash
#
# Launch sets the following environment variables for use in docker-compose
#
#   CDC_HOME: the home directory of the compose app
#   CDC_DBUS_PATH: the path to the unix socket used by dbus or dbus-proxy

set -e

SCRIPTPATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"

if [ -z "$(readlink "$0")" ]; then
    # Non-symlink invokation
    if [ "$1" == "-h" ]; then
	echo "Usage: $0 <action> [args ...]"
	echo
	echo "  action:"
	echo ""
	echo "    - exec: execute the app"
	echo "    - install: run the app installer"
	echo "    - interactive: give a command line prompt in the environment the app executes"
	echo "    - <custom>: apps may define custom actions, see README.md"
	echo ""
	exit 0
    fi
    ACTION="$1"
    shift 1
else
    # Symlink invokation
    ACTION=$(basename "$0")
    cd "$SCRIPTPATH"
fi

APP="$(basename -- "$(pwd -P)")"

OVERRIDE_FILE=$(mktemp /tmp/desktop-containers-override.XXXXXX.yaml)
trap "rm -f '$OVERRIDE_FILE'" EXIT
cat <<EOF > "$OVERRIDE_FILE"
version: "3.8"
x-common:
  x-dummy: dummy
EOF

CONFIG_FILE=""
if [ -e override.yaml ]; then
    CONFIG_FILE="-f override.yaml"
fi

ENV_FILE=""
if [ -e .env ]; then
    ENV_FILE="--env-file .env"
fi


CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    cat <<EOF >> "$OVERRIDE_FILE"
  read_only: false
EOF
fi

cat <<EOF >> "$OVERRIDE_FILE"
services:
  $APP:
    x-dummy: dummy
EOF

if [ "$(podman-compose -f compose.yaml -f override.yaml config | yq ".services.\"$ACTION\".\"x-launcher\".devices")" != "null" ]; then
    for DEVICE in $(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".devices[]"); do
	if [ "$DEVICE" = "video" ]; then
	    cat <<EOF >> "$OVERRIDE_FILE"
    devices:
EOF
	    for dev in /dev/video*; do
		if [ -c "$dev" ]; then
		    echo "      - \"$dev:$dev\"" >> "$OVERRIDE_FILE"
		fi
	    done
	fi
    done
fi

echo "==== OVERRIDE FILE ===="
cat "$OVERRIDE_FILE"
echo "======================="

INTERACTIVE1=""
INTERACTIVE2=""
if [ "$ACTION" == "interactive" ]; then
    INTERACTIVE1="--podman-run-args"
    INTERACTIVE2="\-it"
fi

# Look up container name
CONTAINER_NAME="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".container_name")"
if [ -z "$CONTAINER_NAME" -o "$CONTAINER_NAME" == "null" ]; then
    CONTAINER_NAME="cdc_$APP_$ACTION"
fi
echo "Container name: $CONTAINER_NAME"

# Alternative wayy of finding running container, but I prefer just going directly through podman
#RUNNING_NAME=$(podman-compose -f ./compose.yaml ps --format "{{.Names}}" | awk -F_ -vaction="$ACTION" '{if ($2 == action) { print $2} }')

RUNNING_ID="$(podman ps -q -f "name=$CONTAINER_NAME")"
echo "Running ID: $RUNNING_ID"

export CDC_HOME="$(pwd -P)"

LAUNCH_COMMAND="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".command | .[]")"
if [ -z "$LAUNCH_COMMAND" -o "$LAUNCH_COMMAND" == "null" ]; then
    echo "No launch command defined for this service"
    exit 1
fi

if [ -n "$RUNNING_ID" ]; then
    echo "Container already running; starting process inside running container."
    #podman-compose  --in-pod false -f compose.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE $INTERACTIVE1 $INTERACTIVE2 exec "$ACTION" bash -c 'eval $LAUNCH_COMMAND \"\$@\"' bash "$@"
    podman-compose --env-file "$CDC_HOME/.env" --in-pod false -f compose.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE $INTERACTIVE1 $INTERACTIVE2 exec "$ACTION" bash -c "$LAUNCH_COMMAND" bash "$@"
    exit 0
fi

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID}/bus"
fi

DBUS_PROXY_ARGS="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".\"dbus-proxy\"")"
if [ "$DBUS_PROXY_ARGS" != "null" ]; then
    echo "Launching: xdg-dbus-proxy $DBUS_SESSION_BUS_ADDRESS $XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION $DBUS_PROXY_ARGS"
    xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" "$XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION" --filter $DBUS_PROXY_ARGS &
    DBUS_PROXY_PID=$?
    trap "kill $DBUS_PROXY_PID" EXIT
    export CDC_DBUS_PATH="$XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION"
else
    export CDC_DBUS_PATH="${DBUS_SESSION_BUS_ADDRESS/unix:path=}"
fi

if [ -z "$DBUS_SYSTEM_BUS_ADDRESS" ]; then
    export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
fi

DBUS_SYSTEM_PROXY_ARGS="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".\"dbus-system-proxy\"")"
if [ "$DBUS_SYSTEM_PROXY_ARGS" != "null" ]; then
    echo "Launching: xdg-dbus-proxy $DBUS_SYSTEM_BUS_ADDRESS $XDG_RUNTIME_DIR/bus-system-proxy-$APP-$ACTION $DBUS_SYSTEM_PROXY_ARGS"
    xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" "$XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION" $DBUS_SYSTEM_PROXY_ARGS &
    DBUS_SYSTEM_PROXY_PID=$?
    trap "kill $DBUS_SYSTEM_PROXY_PID" EXIT
    export CDC_DBUS_SYSTEM_PATH="$XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION"
else
    export CDC_DBUS_SYSTEM_PATH="${DBUS_SESSION_BUS_ADDRESS/unix:path=}"
fi

#podman-compose  --in-pod false -f compose.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE $INTERACTIVE1 $INTERACTIVE2 run --name "$CONTAINER_NAME" --rm "$ACTION" bash -c 'eval $LAUNCH_COMMAND \"\$@\"' bash "$@"

TRAY="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".tray")"
if [ -n "$TRAY" -a "$TRAY" != "null" ]; then
    echo "====TRAY===="
    TRAY_NAME="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".tray.name")"
    TRAY_ICON="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".tray.icon")"
    TRAY_WMCLASS="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".tray.\"wmclass\"")"
    TRAY_WMCLASS_ARG=""
    if [ "$TRAY_WMCLASS" == "null" ]; then
	TRAY_WMCLASS_FILE="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$ACTION\".\"x-launcher\".tray.\"wmclass-file\"")"
	if [ "$TRAY_WMCLASS_FILE" != "null" ]; then
	    TRAY_WMCLASS="$(cat "home/$TRAY_WMCLASS_FILE")"
      	    TRAY_WMCLASS_ARG="--wm-class $TRAY_WMCLASS"
	fi
    else
	TRAY_WMCLASS_ARG="--wm-class $TRAY_WMCLASS"
    fi

    TRAY_LAUNCHER="${SCRIPTPATH}/../dependencies/submodules/minimize-to-tray-wrapper/bin/minimize-to-tray-wrapper"
    TRAY_ARGS="--app-name $TRAY_NAME --icon home/$TRAY_ICON $TRAY_WMCLASS_ARG --"
    echo "TRAY: $TRAY_LAUNCHER $TRAY_ARGS"
else
    TRAY_LAUNCHER="exec"
    TRAY_ARGS=""
fi

if [ -n "$CDC_DEBUG" ]; then
    echo "=== CONFIG ==="
    podman-compose  --env-file "$CDC_HOME/.env" --in-pod false -f compose.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE $INTERACTIVE1 $INTERACTIVE2 config
    echo "=============="
fi
    
"$TRAY_LAUNCHER" $TRAY_ARGS podman-compose  --env-file "$CDC_HOME/.env" --in-pod false -f compose.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE $INTERACTIVE1 $INTERACTIVE2 run --name "$CONTAINER_NAME" --rm "$ACTION" bash -c "$LAUNCH_COMMAND" bash "$@"
