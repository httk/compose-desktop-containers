#!/bin/bash

set -e

SCRIPTPATH="$(dirname -- "$(realpath -- "$0")")"

if [ -z "$USER" -o -z "$UID" -o -z "$LANG" ]; then
    echo "The following env variables must be set: USER, UID, LANG"
    exit 1
fi

BASE="ubuntu:24.04"

# The sed 's/.utf8/.UTF-8/' fixes incorrectly specified locales from pre-GNOME 3.18 I think.
LOCALES="$(locale -a | grep -v "POSIX" | sed 's/.utf8/.UTF-8/' | tr '\n' ' ')"

PKGS_FILES=""
PKGS_NODEPS_FILES=""
COMMANDS_FILES=""
PRECOMMANDS_FILES=""

CDC_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cdc"
mkdir -p "$CDC_CONFIG_DIR/image-u24/installed"
ln -sf "$SCRIPTPATH/opt" "$CDC_CONFIG_DIR/image-u24/opt"

PKGS=()
PKGS_NODEPS=()
COMMANDS=()
PRECOMMANDS=()

if [ -n "$(ls "$CDC_CONFIG_DIR/image-u24/installed")" ]; then
    for APP_DIR in "$CDC_CONFIG_DIR"/image-u24/installed/*; do
	echo "Checking image dependencies in $APP_DIR"
	PKGS=( $(yq -r '."x-application".images.u24.pkgs[]? // empty' "$APP_DIR/compose.yaml") )
	echo "Picked up pkgs:" "${PKGS[@]}"
	PKGS_ONLY=( $(yq -r '."x-application".images.u24."pkgs-only[]?" // empty' "$APP_DIR/compose.yaml") )
	echo "Picked up pkgs to be installed without recommendeds:" "${PKGS_ONLY[@]}"
	PRECOMMANDS=( $(yq -r '."x-application".images.u24.precommands[]? // empty' "$APP_DIR/compose.yaml") )
	echo "Picked up pre-commands:" "${PRECOMMANDS[@]}"
	COMMANDS=( $(yq -r '."x-application".images.u24.commands[]? // empty' "$APP_DIR/compose.yaml") )
	echo "Picked up commands:" "${COMMANDS[@]}"
    done
fi

IFS=$'\n'
PKGS+=( $(ls image/*-pkgs* 2>/dev/null | grep -v "~" | sort -s -t- -k1,1n -k2 | xargs cat) )
PKGS_ONLY+=( $(ls image/*-pkgs-only* 2>/dev/null | grep -v "~" | sort -s -t- -k1,1n -k2 | xargs cat) )
COMMANDS+=( $(ls image/*-commands* 2>/dev/null | grep -v "~" | sort -s -t- -k1,1n -k2 | xargs cat) )
PRECOMMANDS+=( $(ls image/*-precommands* 2>/dev/null | grep -v "~" | sort -s -t- -k1,1n -k2 | xargs cat) )
IFS=' '

if [ -n "${PKGS}" ]; then
    PKGS_LINES="RUN apt-get -y install $(printf "%s\n" "${PKGS[@]}" | sort -u | tr '\n' ' ')"
fi
if [ -n "${PKGS_ONLY}" ]; then
    PKGS_ONLY_LINES="RUN apt-get --no-install-recommends -y install $(printf "%s\n" "${PKGS_ONLY[@]}" | sort -u | tr '\n' ' ')"
fi
if [ -n "${COMMANDS}" ]; then
    COMMANDS_LINES="$(printf "%s\n" "${COMMANDS[@]}")"
fi
if [ -n "${PRECOMMANDS}" ]; then
    PRECOMMANDS_LINES="$(printf "%s\n" "${PRECOMMANDS[@]}")"
fi

mkdir -p files
cp /etc/timezone files/timezone

cat > ./Containerfile <<EOF
FROM $BASE
ENV DEBIAN_FRONTEND=noninteractive
COPY files/timezone /etc/timezone
EOF

cat >> ./Containerfile <<EOF
$PRECOMMANDS_LINES
RUN dpkg --add-architecture i386 && apt-get update && apt-get -y dist-upgrade && apt-get install -y --reinstall ca-certificates locales
$PKGS_ONLY_LINES
$PKGS_LINES
RUN apt-get clean autoclean -y && apt-get autoremove -y && rm -rf /var/tmp/* && rm -rf /tmp/*
$COMMANDS_LINES
EOF

LOCALTIME=$(readlink /etc/localtime)
if [ -n "$LOCALTIME" ]; then
    TZ_LOCATION="${LOCALTIME##*/}"
    TZ_AREA="${LOCALTIME%/*}"
    TZ_AREA="${TZ_AREA##*/}"
    echo "RUN ln -sf \"/usr/share/zoneinfo/${TZ_AREA}/${TZ_LOCATION}\" /etc/localtime" >> ./Containerfile
else
    cp /etc/localtime files/localtime
    echo "RUN rm -f /etc/localtime" >> ./Containerfile
    echo "COPY files/localtime /etc/localtime" >> ./Containerfile
fi

cat >> ./Containerfile <<EOF
COPY ./tools/en_SE.locale /tmp/en_SE.locale
RUN test ! -e /usr/share/i18n/locales/en_SE && cp /tmp/en_SE.locale /usr/share/i18n/locales/en_SE && localedef -i en_SE -f UTF-8 en_SE.UTF-8 && echo "# en_SE.UTF-8 UTF-8" >> "/etc/locale.gen" && echo "en_SE.UTF-8 UTF-8" >> "/usr/share/i18n/SUPPORTED"
RUN locale-gen ${LOCALES} && update-locale "LANG=$LANG"
ENV LANG $LANG
RUN groupadd -r -g 5000 build && useradd -m -u 5000 -g 5000 -c "Build user" "build"
EOF

FULLNAME="$(getent passwd rar | awk -F':' '{print $5}')"

# We need to handle the user part differently depnding on if it overlaps the default 1000 user or not.
if [ "$UID" == "1000" ]; then

    cat >> Containerfile <<EOF
RUN usermod -l "$USER" ubuntu && groupmod -n "$USER" ubuntu && usermod -d "/home/$USER" -m "$USER" && usermod -c "$FULLNAME" "$USER" && mkdir /tmp/$USER && chown "$USER:$USER" "/tmp/$USER" && chmod 0700 "/tmp/$USER" && mkdir "/tmp/$USER/run" && chown "$USER:$USER" "/tmp/$USER/run" && chmod 0700 "/tmp/$USER/run"
EOF

else

    cat >> Containerfile <<EOF
RUN groupadd -r -g "$UID" "$USER" && useradd -m -u "$UID" -g "$UID" -c "$FULLNAME" "$USER" && mkdir /tmp/$USER && chown "$USER:$USER" "/tmp/$USER" && chmod 0700 "/tmp/$USER" && mkdir "/tmp/$USER/run" && chown "$USER:$USER" "/tmp/$USER/run" && chmod 0700 "/tmp/$USER/run"
EOF

fi

cat >> Containerfile <<EOF
RUN mkdir -p /run/user && ln -s "/tmp/$USER/run" "/run/user/${UID}"
EOF

podman build -t cdc-u24 --label=wrap .
podman image prune -f --filter label=wrap

podman run --rm -w "/home/$USER" --user="$USER" --shm-size=512M --cap-drop=ALL --read-only --read-only-tmpfs --userns=keep-id --name "cdc_test_u24" cdc-u24 echo "Container finished."
