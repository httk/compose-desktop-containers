#!/usr/bin/bash

set -e 

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ "$1" == "-h" ]; then
    echo "Usage: $0 [<app dir>]"
    exit 0
fi

DEST="$1"
if [ "$DEST" != "" ]; then
    cd "$DEST"
fi
APP="$(basename -- "$(pwd -P)")"
DEST_ABSPATH="$(pwd -P)"

if [ "$(yq '."x-application".launchers' compose.yaml)" != "null" ]; then
    for LAUNCHER in $(yq -r '."x-application".launchers | keys[]' compose.yaml); do
	ln -sf "$SCRIPTPATH/launch.sh" "$LAUNCHER"
	if [ "$(yq ".\"x-application\".launchers.\"$LAUNCHER\".desktop" compose.yaml)" != "null" ]; then
	    mkdir -p ~/.local/share/applications
	    yq -r ".\"x-application\".launchers.\"$LAUNCHER\".desktop.file" compose.yaml | sed "s|^Exec=.*\$|Exec=\"${DEST_ABSPATH}/$APP\" %U|" > ~/.local/share/applications/"${LAUNCHER}_container.desktop"
	    echo "Wrote: ~/.local/share/applications/${LAUNCHER}_container.desktop"

	    ICONS_NBR=$(yq -r ".\"x-application\".launchers.\"$LAUNCHER\".desktop.icons | length" compose.yaml)
	    for (( ICON_IDX=0; ICON_IDX<ICONS_NBR; ICON_IDX++ )); do
		# Sanetize icon paths somewhat
		ICON_SRC=$(yq -r ".\"x-application\".launchers.\"$LAUNCHER\".desktop.icons[$ICON_IDX].source" compose.yaml)
		ICON_SRC=${ICON_SRC//[^[:ascii:]]}
		ICON_SRC=${ICON_SRC//../}
		ICON_DEST=$(yq -r ".\"x-application\".launchers.\"$LAUNCHER\".desktop.icons[$ICON_IDX].dest" compose.yaml)
		ICON_DEST=${ICON_DEST//[^[:ascii:]]}
		ICON_DEST=${ICON_DEST//\/}
		ICON_DEST=${ICON_DEST//../}
		ICON_SIZE=$(yq -r ".\"x-application\".launchers.\"$LAUNCHER\".desktop.icons[$ICON_IDX].size" compose.yaml)
		if [ "$ICON_SIZE" = "scaleable" ]; then
		    ICON_SIZE_DIR="scaleable"
		elif [ "$ICON_SIZE" = "512" -o "$ICON_SIZE" = "256" -o "$ICON_SIZE" = "192" -o "$ICON_SIZE" = "128" -o "$ICON_SIZE" = "96" -o "$ICON_SIZE" = "72" -o "$ICON_SIZE" = "64" -o "$ICON_SIZE" = "48" -o "$ICON_SIZE" = "36" -o "$ICON_SIZE" = "32" -o "$ICON_SIZE" = "24" -o "$ICON_SIZE" = "22" -o "$ICON_SIZE" = "16" -o "$ICON_SIZE" = "8" ]; then
		    ICON_SIZE_DIR="${ICON_SIZE}x${ICON_SIZE}"
		else
		    echo "Warning: invalid icon size for $ICON_SRC"
		    continue
		fi
		if [ -e "home/$ICON_SRC" ]; then
		    mkdir -p ~/.local/share/icons/hicolor/"$ICON_SIZE_DIR"/apps
		    cp "home/$ICON_SRC" ~/.local/share/icons/hicolor/"$ICON_SIZE_DIR"/apps/"$ICON_DEST"
		    echo "Wrote: ~/.local/share/icons/hicolor/$ICON_SIZE_DIR/apps/$ICON_DEST"
		else
		    echo "Warning: icon 'home/$ICON_SRC' does not exist."
		fi
	    done
	   
	    update-desktop-database ~/.local/share/applications/
	    gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
	fi
    done    
fi
