#!/bin/bash

set -e

if [ -z "$XDG_RUNTIME_DIR" -o -z "$USER" -o -z "$UID" -o -z "$LANG" ]; then
    echo "The following env variables must be set: XDG_RUNTIME_DIR, USER, UID, LANG"
    exit 1
fi

BASE="ubuntu:24.04"

# The sed 's/.utf8/.UTF-8/' fixes incorrectly specified locales from pre-GNOME 3.18 I think.
LOCALES="$(locale -a | grep -v "POSIX" | sed 's/.utf8/.UTF-8/' | tr '\n' ' ')"

PKGS_FILES=""
PKGS_NODEPS_FILES=""
COMMANDS_FILES=""
PRECOMMANDS_FILES=""

for SUBDIR in ./image ../../*/image; do
    IMGDIR="${SUBDIR%/home}"
    PKGS_FILES="$PKGS_FILES $(ls "$IMGDIR"/*-pkgs* -I "*~" 2>/dev/null || true)"
    PKGS_NODEPS_FILES="$PKGS_NODEPS_FILES $(ls "$IMGDIR"/*-nodeps-pkgs* -I "*~" 2>/dev/null || true)"
    COMMANDS_FILES="$COMMANDS_FILES $(ls "$IMGDIR"/*-commands* 2>/dev/null -I "*~" || true)"
    PRECOMMANDS_FILES="$PRECOMMANDS_FILES $(ls "$IMGDIR"/*-precommands* -I "*~" 2>/dev/null || true)"
done

PKGS_FILES="$(echo "$PKGS_FILES" | sort -s -t- -k1,1n -k2)"
PKGS_NODEPS_FILES="$(echo "$PKGS_NODEPS_FILES" | sort -s -t- -k1,1n -k2)"
COMMANDS_FILES="$(echo "$COMMANDS_FILES" | sort -s -t- -k1,1n -k2)"
PRECOMMANDS_FILES="$(echo "$PRECOMMANDS_FILES" | sort -s -t- -k1,1n -k2)"

PKGS=""
PKGS_NODEPS=""
COMMANDS=""
PRECOMMANDS=""

if [ -n "${PKGS_FILES// }" ]; then
    PKGS="RUN apt-get -y install $(awk 1 $PKGS_FILES | sort -u | tr '\n' ' ')"
fi
if [ -n "${PKGS_NODEPS_FILES// }" ]; then
    PKGS_NODEPS="RUN apt-get --no-install-recommends -y install $(awk 1 $PKGS_NODEPS_FILES | sort -u | tr '\n' ' ')"
fi
if [ -n "${COMMANDS_FILES// }" ]; then
    COMMANDS="$(awk 1 $COMMANDS_FILES)"
fi
if [ -n "${PRECOMMANDS_FILES// }" ]; then
    PRECOMMANDS="$(awk 1 $PRECOMMANDS_FILES)"
fi

cat > ./Containerfile <<EOF
FROM $BASE
$PRECOMMANDS
RUN apt-get update && apt-get -y dist-upgrade && apt-get install -y --reinstall ca-certificates
$PKGS_NODEPS
$PKGS
$COMMANDS
RUN test ! -e /usr/share/i18n/locales/en_SE && cp /tmp/en_SE.locale /usr/share/i18n/locales/en_SE && localedef -i en_SE -f UTF-8 en_SE.UTF-8 && echo "# en_SE.UTF-8 UTF-8" >> "/etc/locale.gen" && echo "en_SE.UTF-8 UTF-8" >> "/usr/share/i18n/SUPPORTED"
RUN locale-gen ${LOCALES} && update-locale "LANG=$LANG"
ENV LANG $LANG
RUN groupadd -r -g 5000 build && useradd -m -u 5000 -g 5000 -c "Build user" "build" && ln -s "/tmp/$USER/run" "$XDG_RUNTIME_DIR"
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

podman build -t desktop-container-u24 --label=wrap .
podman tag desktop-container-u24 desktop-container-default
podman image prune -f --filter label=wrap

echo "desktop-container-default" > image.info
