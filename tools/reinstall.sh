#!/bin/bash

set -e 

SCRIPTPATH="$(dirname -- "$(realpath -- "$0")")"
DEST_ABSPATH="$(cd -- "$DEST"; pwd -P)"

if ! yq -r '."x-application"' compose.yaml > /dev/null 2>&1 || [ "$(yq -r '."x-application"' "$SOURCE" 2>/dev/null)" == "null" ]; then

    echo "=== Error dump ==="
    yq -r '."x-application"' "$SOURCE" && true
    echo "=================="

    echo "The file compose.yaml in this directory does not seem to be a valid compose-desktop-container yaml file."
    exit 1
fi

if [ ! -e override.yaml ]; then
    if [ "$(yq -r '."x-application"."override-default"' compose.yaml)" != "null" ]; then
	yq -r '."x-application"."override-default"' compose.yaml > override.yaml
    else
	cat <<EOF > override.yaml
version: "3.8"
EOF
    fi
fi

if [ ! -e .env ]; then
    if [ "$(yq -r '."x-application"."env-default"' compose.yaml)" != "null" ]; then
	yq -r '."x-application"."env-default"' compose.yaml > .env
    else
	cat <<EOF > .env
# No configurable options
EOF
    fi
    if [ ! -e env ]; then
	ln -s .env env
    fi
fi

if [ "$(yq -r '."x-application"."readme"' compose.yaml)" != "null" ]; then
    yq -r '."x-application"."readme"' compose.yaml > README.md
else
    cat <<EOF > README.md
This app is missing a README.
EOF
fi

"$SCRIPTPATH/launch.sh" install-prepare
"$SCRIPTPATH/launch.sh" install
"$SCRIPTPATH/post-install.sh"
