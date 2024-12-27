#!/bin/bash

set -e 

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ -z "$1" -o "$1" == "-h" -o "$1" == "--help" -o -z "$2" -o ! -e "$1" ]; then
    echo "Usage: $0 <app.yaml> [<install dest>]"
    exit 0
fi

SOURCE="$1"
DEST="$2"
if [ "$DEST" == "" ]; then
    SOURCE_NAME=$(basename -- "$SOURCE")
    APP="${SOURCE_NAME%.*}"
    DEST="./$APP"
else
    APP=$(basename -- "$DEST")
fi
shift 2

mkdir -p "$DEST"
DEST_ABSPATH="$(cd -- "$DEST"; pwd -P)"
cp "$SOURCE" "$DEST_ABSPATH/$APP.yaml"
cd "$DEST_ABSPATH"

if [ ! -e config.yaml ]; then
    if [ "$(yq -r '."x-desktop-containers"."config-default"' "$APP.yaml")" != "null" ]; then
	yq -r '."x-desktop-containers"."config-default"' "$APP.yaml" > config.yaml
    else
	cat <<EOF > config.yaml
version: "3.8"

# This container has no configurable options
EOF
    fi
fi

"$SCRIPTPATH/launch.sh" install "$APP"

ln -sf "$SCRIPTPATH/launch.sh" "$APP"

if [ "$(yq '."x-desktop-containers".desktop' $APP.yaml)" != "null" ]; then
    mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
    ENTRIES="$(yq '."x-desktop-containers".desktop | keys[]' $APP.yaml)"
    for ENTRY in $ENTRIES; do
	yq -r '."x-desktop-containers".desktop.$ENTRY.file' $APP.yaml | sed "s|^Exec=.*\$|Exec=\"${DEST_ABSPATH}/$APP\" %U|" > ~/.local/share/applications/"$ENTRY_container.desktop"
	ICONS_NBR=$(yq -r '."x-desktop-containers".desktop.zoom.icons | length')
	for ICON_IDX in $(seq 0 "$ICONS_NBR"); do
	    ICON_SRC=$(yq -r ".\"x-desktop-containers\".desktop.$ENTRY.icons[$ICON_IDX].source" $APP.yaml)
	    ICON_DEST=$(yq -r ".\"x-desktop-containers\".desktop.$ENTRY.icons[$ICON_IDX].dest" $APP.yaml)
	    if [ -e "home/$ICON_SRC" ]; then
		cp "home/$ICON_SRC" "~/.local/share/icons/$DEST"
	    fi
	done
    done
    update-desktop-database ~/.local/share/applications/
    gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
fi
