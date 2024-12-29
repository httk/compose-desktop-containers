#!/bin/bash
#
# Launch sets the following environment variables for use in docker-compose
#
#   COMPOSE_APP_HOME: the home directory of the compose app
#   COMPOSE_APP_DBUS_PATH: the path to the unix socket used by dbus or dbus-proxy

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
if [ -e config.yaml ]; then
    CONFIG_FILE="-f config.yaml"
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

if [ "$(yq ".\"x-application\".launchers.\"$APP\".devices" compose.yaml)" != "null" ]; then
    for DEVICE in $(yq -r ".\"x-application\".launchers.\"$APP\".devices[]" compose.yaml); do
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
CONTAINER_NAME="$(yq -r ".services.\"$APP\".container_name" compose.yaml)"
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME="htdc_$APP_$ACTION"
fi
echo "Container name: $CONTAINER_NAME $(pwd -P)"

# Alternative way of finding running container, but I prefer just going directly through podman
#RUNNING_NAME=$(podman-compose -f ./compose.yaml ps --format "{{.Names}}" | awk -F_ -vaction="$ACTION" '{if ($2 == action) { print $2} }')

RUNNING_ID="$(podman ps -q -f "name=$CONTAINER_NAME")"
echo "Running ID: $RUNNING_ID"

export COMPOSE_APP_HOME="$(pwd -P)"

if [ -n "$RUNNING_ID" ]; then
    echo "Container already running; starting process inside running container."
    podman-compose  --in-pod false -f compose.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE $INTERACTIVE1 $INTERACTIVE2 exec "$ACTION" bash -c 'eval $LAUNCH_COMMAND \"\$@\"' bash "$@"
    exit 0
fi

DBUS_PROXY_ARGS="$(yq -r ".\"x-application\".launchers.\"$APP\".\"dbus-proxy\"" compose.yaml)"
if [ -n "$DBUS_PROXY_ARGS" -a "$DBUS_PROXY_ARGS" != "null" ]; then
    echo "Launching: xdg-dbus-proxy $DBUS_SESSION_BUS_ADDRESS $XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION $DBUS_PROXY_ARGS"
    xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" "$XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION" --filter $DBUS_PROXY_ARGS &
    DBUS_PROXY_PID=$?
    trap "kill $DBUS_PROXY_PID" EXIT
    export COMPOSE_APP_DBUS_PATH="$XDG_RUNTIME_DIR/bus-proxy-$APP-$ACTION-x"
else
    export COMPOSE_APP_DBUS_PATH="${DBUS_SESSION_BUS_ADDRESS/unix:path=}"
fi

podman-compose  --in-pod false -f compose.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE $INTERACTIVE1 $INTERACTIVE2 run --name "$CONTAINER_NAME" --rm "$ACTION" bash -c 'eval $LAUNCH_COMMAND \"\$@\"' bash "$@"
