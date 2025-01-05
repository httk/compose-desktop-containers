#!/bin/bash

set -e 

SCRIPTPATH="$(dirname -- "$(realpath -- "$0")")"

if [ -z "$1" -o "$1" == "-h" -o "$1" == "--help" -o ! -e "$1" ]; then
    echo "Usage: $0 <compose.yaml> [<install dest>]"
    exit 0
fi

SOURCE="$1"
DEST="$2"
if [ -z "$DEST" ]; then
    SOURCE_NAME=$(basename -- "$SOURCE")
    APP="${SOURCE_NAME%.*}"
    DEST="./$APP"
else
    APP=$(basename -- "$DEST")
fi

if ! yq -r '."x-application"' "$SOURCE" > /dev/null 2>&1 || [ "$(yq -r '."x-application"' "$SOURCE" 2>/dev/null)" == "null" ]; then

    echo "=== Error dump ==="
    yq -r '."x-application"' "$SOURCE" && true
    echo "=================="

    echo "This does not seem to be a valid desktop-container yaml file."
    exit 1
fi

mkdir -p "$DEST"
DEST_ABSPATH="$(cd -- "$DEST"; pwd -P)"
ln -sf "$(realpath -- "$SOURCE")" "$DEST_ABSPATH/compose.yaml"
cd "$DEST_ABSPATH"

"$SCRIPTPATH/reinstall.sh"

