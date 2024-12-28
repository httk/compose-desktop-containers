#!/bin/bash

set -e 

SCRIPTPATH="$(dirname -- "$(realpath -- "$0")")"

if [ "$1" == "-h" ]; then
    echo "Usage: $0 [<app dir>]"
    exit 0
fi

DEST="$1"
if [ -n "$DEST" ]; then
    cd "$DEST"
fi
APP="$(basename -- "$(pwd -P)")"

if ! "$SCRIPTPATH/launch.sh" update-check; then
    "$SCRIPTPATH/launch.sh" update-prepare
    "$SCRIPTPATH/launch.sh" update
else
    echo "Update not needed: just running post-install (run install action to force full re-install)."
fi
"$SCRIPTPATH/post-install.sh"
