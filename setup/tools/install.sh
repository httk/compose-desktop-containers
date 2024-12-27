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

if ! yq -r '."x-desktop-containers"' "$SOURCE" > /dev/null 2>&1 || [ "$(yq -r '."x-desktop-containers"' "$SOURCE" 2>/dev/null)" == "null" ]; then
    echo "This is not a desktop-container yaml file."
    #yq -r '."x-desktop-containers"' "$SOURCE"
    exit 1
fi

mkdir -p "$DEST"
DEST_ABSPATH="$(cd -- "$DEST"; pwd -P)"
cp "$SOURCE" "$DEST_ABSPATH/app.yaml"
cd "$DEST_ABSPATH"

if [ ! -e config.yaml ]; then
    if [ "$(yq -r '."x-desktop-containers"."config-default"' app.yaml)" != "null" ]; then
	yq -r '."x-desktop-containers"."config-default"' app.yaml > config.yaml
    else
	cat <<EOF > config.yaml
version: "3.8"

# This container has no configurable options
EOF
    fi
fi

if [ "$(yq -r '."x-desktop-containers"."readme"' app.yaml)" != "null" ]; then
    yq -r '."x-desktop-containers"."readme"' app.yaml > README.md
else
    cat <<EOF > README.md
This app is missing a README.
EOF
fi

"$SCRIPTPATH/launch.sh" install "$APP"

if [ "$(yq '."x-desktop-containers".launchers' app.yaml)" != "null" ]; then
    for LAUNCHER in $(yq -r '."x-desktop-containers".launchers | keys[]' app.yaml); do
	ln -sf "$SCRIPTPATH/launch.sh" "$LAUNCHER"
	if [ "$(yq ".\"x-desktop-containers\".launchers.\"$LAUNCHER\".desktop" app.yaml)" != "null" ]; then
	    mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
	    
	    yq -r ".\"x-desktop-containers\".launchers.\"$LAUNCHER\".desktop.file" app.yaml | sed "s|^Exec=.*\$|Exec=\"${DEST_ABSPATH}/$APP\" %U|" > ~/.local/share/applications/"$LAUNCHER_container.desktop"

	    ICONS_NBR=$(yq -r ".\"x-desktop-containers\".launchers.\"$LAUNCHER\".desktop.icons | length" app.yaml)
	    for (( ICON_IDX=0; ICON_IDX<ICONS_NBR; ICON_IDX++ )); do
		# Sanetize icon paths somewhat
		ICON_SRC=$(yq -r ".\"x-desktop-containers\".launchers.\"$LAUNCHER\".desktop.icons[$ICON_IDX].source" app.yaml)
		ICON_SRC=${ICON_SRC//[^[:ascii:]]}
		ICON_SRC=${ICON_SRC//../}
		ICON_DEST=$(yq -r ".\"x-desktop-containers\".launchers.\"$LAUNCHER\".desktop.icons[$ICON_IDX].dest" app.yaml)
		ICON_DEST=${ICON_DEST//[^[:ascii:]]}
		ICON_DEST=${ICON_DEST//[.\/]}
		ICON_DEST=${ICON_DEST//../}
		ICON_SIZE=$(yq -r ".\"x-desktop-containers\".launchers.\"$LAUNCHER\".desktop.icons[$ICON_IDX].size" app.yaml)
		if [ "$ICON_SIZE" = "scaleable" ]; then
		    ICON_SIZE_DIR="scaleable"
		elif [ "$ICON_SIZE" = "512" -o "$ICON_SIZE" = "256" -o "$ICON_SIZE" = "192" -o "$ICON_SIZE" = "128" -o "$ICON_SIZE" = "96" -o "$ICON_SIZE" = "72" -o "$ICON_SIZE" = "64" -o "$ICON_SIZE" = "48" -o "$ICON_SIZE" = "36" -o "$ICON_SIZE" = "32" -o "$ICON_SIZE" = "24" -o "$ICON_SIZE" = "22" -o "$ICON_SIZE" = "16" -o "$ICON_SIZE" = "8" ]; then
		    ICON_SIZE_DIR="${ICON_SIZE}x${ICON_SIZE}"
		else
		    echo "Warning: invalid icon size for $ICON_SRC"
		    continue
		fi
		if [ -e "home/$ICON_SRC" ]; then
		    mkdir -p "~/.local/share/icons/hicolor/$ICON_SIZE_DIR/apps"
		    cp "home/$ICON_SRC" "~/.local/share/icons/hicolor/$ICON_SIZE_DIR/apps/$ICON_DEST"
		else
		    echo "Warning: icon 'home/$ICON_SRC' does not exist."
		fi
	    done
	   
	    update-desktop-database ~/.local/share/applications/
	    gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
	fi
    done    
fi
