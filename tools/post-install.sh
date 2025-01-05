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

for LAUNCHER in $(podman-compose -f compose.yaml -f override.yaml config | yq -r '.services | keys[]'); do
    if [ "$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$LAUNCHER\".\"x-launcher\"")" != "null" ]; then
	ln -sf "$SCRIPTPATH/launch.sh" "$LAUNCHER"
	if [ "$(podman-compose -f compose.yaml -f override.yaml config | yq ".services.\"$LAUNCHER\".\"x-launcher\".desktop")" != "null" ]; then
	    mkdir -p ~/.local/share/applications
	    podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$LAUNCHER\".\"x-launcher\".desktop.file" > ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	    sed -i "s|^Exec=$LAUNCHER|Exec=\"${DEST_ABSPATH}/$LAUNCHER\"|" ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	    WMCLASS_FILE="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$LAUNCHER\".\"x-launcher\".desktop.\"wmclass-file\"")"
	    if [ -n "$WMCLASS_FILE" -a "$WMCLASS_FILE" != "null" ]; then
		WMCLASS=$(cat "home/$WMCLASS_FILE")
		sed -i "s|^StartupWMClass=.*\$|StartupWMClass=$WMCLASS|" ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	    fi
	    desktop-file-validate ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	    echo "Wrote: ~/.local/share/applications/${LAUNCHER}_cdc.desktop"

	    ICONS_NBR=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$LAUNCHER\".\"x-launcher\".desktop.icons | length")
	    for (( ICON_IDX=0; ICON_IDX<ICONS_NBR; ICON_IDX++ )); do
		# Sanetize icon paths somewhat
		ICON_SRC=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$LAUNCHER\".\"x-launcher\".desktop.icons[$ICON_IDX].source")
		ICON_SRC=${ICON_SRC//[^[:ascii:]]}
		ICON_SRC=${ICON_SRC//../}
		ICON_DEST=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$LAUNCHER\".\"x-launcher\".desktop.icons[$ICON_IDX].dest")
		ICON_DEST=${ICON_DEST//[^[:ascii:]]}
		ICON_DEST=${ICON_DEST//../}
		ICON_SIZE=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".services.\"$LAUNCHER\".\"x-launcher\".desktop.icons[$ICON_IDX].size")
		if [ "$ICON_SIZE" = "null" -o -z "$ICON_SIZE" ]; then
		    DEST_DIRNAME=$(dirname "$ICON_DEST")
		    mkdir -p ~/.local/share/"$APP/$DEST_DIRNAME"
		    cp "home/$ICON_SRC" ~/.local/share/"$APP/$ICON_DEST"
		    echo "Wrote: ~/.local/share/$APP/$ICON_DEST"
		    continue
		elif [ "$ICON_SIZE" = "scalable" ]; then
		    ICON_SIZE_DIR="scalable"
		elif [ "$ICON_SIZE" = "512" -o "$ICON_SIZE" = "256" -o "$ICON_SIZE" = "192" -o "$ICON_SIZE" = "128" -o "$ICON_SIZE" = "96" -o "$ICON_SIZE" = "72" -o "$ICON_SIZE" = "64" -o "$ICON_SIZE" = "48" -o "$ICON_SIZE" = "36" -o "$ICON_SIZE" = "32" -o "$ICON_SIZE" = "24" -o "$ICON_SIZE" = "22" -o "$ICON_SIZE" = "16" -o "$ICON_SIZE" = "8" ]; then
		    ICON_SIZE_DIR="${ICON_SIZE}x${ICON_SIZE}"
		else
		    echo "Warning: invalid icon size for $ICON_SRC: '$ICON_SIZE'"
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
    fi
done

if [ "$(podman-compose -f compose.yaml -f override.yaml config | yq -r '."x-application"."global-launcher"')" != "null" ]; then
    LAUNCHER="$(podman-compose -f compose.yaml -f override.yaml config | yq -r '."x-application"."global-launcher".name')"
    ln -sf "$SCRIPTPATH/launch-global.sh" "$LAUNCHER"
    if [ "$(podman-compose -f compose.yaml -f override.yaml config | yq '."x-application"."global-launcher".desktop')" != "null" ]; then
	mkdir -p ~/.local/share/applications
	podman-compose -f compose.yaml -f override.yaml config | yq -r '."x-application"."global-launcher".desktop.file' > ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	sed -i "s|^Exec=$LAUNCHER|Exec=\"${DEST_ABSPATH}/$LAUNCHER\"|" ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	WMCLASS_FILE="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".desktop.\"wmclass-file\"")"
	if [ -n "$WMCLASS_FILE" -a "$WMCLASS_FILE" != "null" ]; then
	    WMCLASS=$(cat "home/$WMCLASS_FILE")
	    sed -i "s|^StartupWMClass=.*\$|StartupWMClass=$WMCLASS|" ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	fi
	desktop-file-validate ~/.local/share/applications/"${LAUNCHER}_cdc.desktop"
	echo "Wrote: ~/.local/share/applications/${LAUNCHER}_cdc.desktop"

	ICONS_NBR=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".desktop.icons | length")
	for (( ICON_IDX=0; ICON_IDX<ICONS_NBR; ICON_IDX++ )); do
	    # Sanetize icon paths somewhat
	    ICON_SRC=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".desktop.icons[$ICON_IDX].source")
	    ICON_SRC=${ICON_SRC//[^[:ascii:]]}
	    ICON_SRC=${ICON_SRC//../}
	    ICON_DEST=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".desktop.icons[$ICON_IDX].dest")
	    ICON_DEST=${ICON_DEST//[^[:ascii:]]}
	    ICON_DEST=${ICON_DEST//../}
	    ICON_SIZE=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".desktop.icons[$ICON_IDX].size")
	    if [ "$ICON_SIZE" = "null" -o -z "$ICON_SIZE" ]; then
		DEST_DIRNAME=$(dirname "$ICON_DEST")
		mkdir -p ~/.local/share/"$APP/$DEST_DIRNAME"
		cp "home/$ICON_SRC" ~/.local/share/"$APP/$ICON_DEST"
		echo "Wrote: ~/.local/share/$APP/$ICON_DEST"
		continue
	    elif [ "$ICON_SIZE" = "scalable" ]; then
		ICON_SIZE_DIR="scalable"
	    elif [ "$ICON_SIZE" = "512" -o "$ICON_SIZE" = "256" -o "$ICON_SIZE" = "192" -o "$ICON_SIZE" = "128" -o "$ICON_SIZE" = "96" -o "$ICON_SIZE" = "72" -o "$ICON_SIZE" = "64" -o "$ICON_SIZE" = "48" -o "$ICON_SIZE" = "36" -o "$ICON_SIZE" = "32" -o "$ICON_SIZE" = "24" -o "$ICON_SIZE" = "22" -o "$ICON_SIZE" = "16" -o "$ICON_SIZE" = "8" ]; then
		ICON_SIZE_DIR="${ICON_SIZE}x${ICON_SIZE}"
	    else
		echo "Warning: invalid icon size for $ICON_SRC: '${ICON_SIZE}'"
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
fi
