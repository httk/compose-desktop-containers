#!/bin/bash
#

set -e

SCRIPTPATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"

if [ -z "$(readlink "$0")" ]; then
    # Non-symlink invokation
    if [ "$1" == "-h" ]; then
	echo "Usage: $0 <action> [args ...]"
	exit 0
    fi
    ACTION="$1"
    shift 1
else
    # Symlink invokation
    cd "$SCRIPTPATH"
    ACTION="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".\"default-action\"")"
fi

APP="$(basename -- "$(pwd -P)")"

GLOBAL_LAUNCHER="$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\"")"
if [ -z "$GLOBAL_LAUNCHER" -o "$GLOBAL_LAUNCHER" = "null" ]; then
    echo "This app has no global launcher"
    exit 1
fi

if [ "$ACTION" == "tray" ]; then
    if [ "$(podman-compose -f compose.yaml -f override.yaml config | yq ".\"x-application\".\"global-launcher\".tray")" == "null" ]; then
	echo "Action: tray requested, with no tray definition"
	exit 1
    fi
    echo "== MULTI-TRAY MODE =="
    MULTI_TRAY_ARGS=""
    ICON="$(podman-compose -f compose.yaml -f override.yaml config | yq ".\"x-application\".\"global-launcher\".tray.icon")"
    ENTRY_NBR=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".tray.entries | length")
    for (( ENTRY_IDX=0; ENTRY_IDX<ENTRY_NBR; ENTRY_IDX++ )); do
	ENTRY_NAME=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".tray.entries[$ENTRY_IDX].name")
	ENTRY_WMCLASS=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".tray.entries[$ENTRY_IDX].wmclass")
	if [ "$ENTRY_WMCLASS" = "null" ]; then
	    ENTRY_WMCLASS_FILE=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".tray.entries[$ENTRY_IDX].\"wmclass-file\"")
	    if [ "$ENTRY_WMCLASS_FILE" != "null" ]; then
		ENTRY_WMCLASS=$(cat "home/$ENTRY_WMCLASS_FILE")
	    fi
	fi
	ENTRY_LAUNCH=$(podman-compose -f compose.yaml -f override.yaml config | yq -r ".\"x-application\".\"global-launcher\".tray.entries[$ENTRY_IDX].launch")
	MULTI_TRAY_ARGS="$MULTI_TRAY_ARGS --app \"$ENTRY_NAME\" \"$ENTRY_WMCLASS\" \"./$ENTRY_LAUNCH\""
    done
    
    echo Executing: /usr/bin/env --split-string="\"$SCRIPTPATH/../dependencies/submodules/minimize-to-tray-wrapper/bin/multi-app-tray\" --icon \"$ICON\" $MULTI_TRAY_ARGS"
    /usr/bin/env --split-string="\"$SCRIPTPATH/../dependencies/submodules/minimize-to-tray-wrapper/bin/multi-app-tray\" --icon \"$ICON\" $MULTI_TRAY_ARGS"
    RUNNING_CONTAINERS="$(podman ps -q -f "name=cdc_$APP_*")"
    if [ -n "$RUNNING_CONTAINERS" ]; then
	   podman kill ${RUNNING_CONTAINERS}
    fi
    exit 0
fi

exec "./$ACTION" "$@"
exit 1
