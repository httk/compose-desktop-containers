#!/bin/bash

set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
APPNAME=$(basename "$SCRIPTPATH")

if [ -z "$(readlink "$0")" ]; then
    # Non-symlink invokation
    if [ "$1" == "-h" ]; then
	echo "Usage: $0 <action> <app> [args ...]"
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
    TYPE="$1"
    APP="$2"
    shift 2
else
    # Symlink invokation
    APP="$APPNAME"
    TYPE=$(basename "$0")
    if [ "$TYPE" == "$APPNAME" ]; then
	TYPE=exec
    fi
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd "${SCRIPTPATH}/../../$APP"

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

if [ "$(yq ".\"x-desktop-containers\".launchers.\"$APP\".devices" app.yaml)" != "null" ]; then
    for DEVICE in $(yq -r ".\"x-desktop-containers\".launchers.\"$APP\".devices[]" app.yaml); do
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

if [ "$TYPE" != "interactive" ]; then
    podman-compose --in-pod false -f app.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE run --rm "$TYPE" bash -c 'eval $LAUNCH_COMMAND "$@"' bash "$@"
else
    podman-compose --in-pod false -f app.yaml -f "$OVERRIDE_FILE" $CONFIG_FILE --podman-run-args "\-it" run --rm exec bash
fi
