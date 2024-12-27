#!/bin/bash

set -e 

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

OVERRIDE_FILE=$(mktemp /tmp/desktop-containers-override.XXXXXX.yaml)
trap "rm -f '$OVERRIDE_FILE'" EXIT
cat <<EOF > "$OVERRIDE_FILE"
version: "3.8"
x-common:
  x-dummy: dummy
EOF

CRUNVER="$(crun --version | awk '/crun version /{print $3}')"
if ! sort -C -V <<< $'1.9.1\n'"$CRUNVER"; then
    cat <<EOF >> "$OVERRIDE_FILE"
  read_only: false
EOF
fi

TYPE="$1"
APP="$2"
shift 2

cd "${SCRIPTPATH}/../../$APP"

if [ "$(yq '."x-desktop-containers".devices.video' $APP.yaml)" != "null" ]; then
    SERVICES="$(yq '."x-desktop-containers".devices.video[]' $APP.yaml)"
    cat <<EOF >> "$OVERRIDE_FILE"
services:
EOF
    for SERVICE in $SERVICES; do
	cat <<EOF >> "$OVERRIDE_FILE"
  $SERVICE:
    devices:
EOF
	for dev in /dev/video*; do
	    if [ -c "$dev" ]; then
		echo "      - \"$dev:$dev\"" >> "$OVERRIDE_FILE"
	    fi
	done
    done
fi

echo "==== OVERRIDE FILE ===="
cat "$OVERRIDE_FILE"
echo "======================="

podman-compose --in-pod false -f "$APP.yaml" -f "$OVERRIDE_FILE" run --rm "$TYPE" bash -c 'eval $LAUNCH_COMMAND "$@"' bash "$@"

if [ "$TYPE" == "install" -a "$(yq '."x-desktop-containers".desktop' $APP.yaml)" != "null" ]; then	
    mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications
    ENTRIES="$(yq '."x-desktop-containers".desktop | keys[]' $APP.yaml)"
    for ENTRY in $ENTRIES; do
	yq -r '."x-desktop-containers".desktop.$ENTRY.file' $APP.yaml | sed "s|^Exec=.*\$|Exec=\"${IMAGE_DIR}/exec-zoom.sh\" %U|" > ~/.local/share/applications/"$ENTRY_container.desktop"
	ICON=$(yq -r '."x-desktop-containers".desktop.$ENTRY.icon' $APP.yaml)
	if [ -e "home/$ICON" ]; then
	    cp "home/$ICON" ~/.local/share/icons/hicolor/256x256/apps/"$ENTRY.png"
	fi
    done
    update-desktop-database ~/.local/share/applications/
    gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
fi
