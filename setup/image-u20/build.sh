#!/bin/bash

set -e

BASE="ubuntu:20.04"

# The sed 's/.utf8/.UTF-8/' fixes incorrectly specified locales from pre-GNOME 3.18 I think.
LOCALES="$(locale -a | grep -v "POSIX\|C" | sed 's/.utf8/.UTF-8/' | tr '\n' ' ')"

cat > ./Containerfile <<EOF
FROM $BASE
ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/Stockholm
RUN apt-get update && apt-get -y dist-upgrade && apt-get install -y --reinstall ca-certificates 
RUN apt-get -y --no-install-recommends install locales nano wget bash curl git jq less net-tools p7zip-full patch pciutils pkg-config procps psmisc psutils rsync screen unzip xmlstarlet xz-utils python3 python3-pip python3-setuptools python3-venv libx11-data gpg gpg-agent xdg-utils iproute2 alsa-utils && apt-get clean autoclean -y && apt-get autoremove -y && rm -rf /var/tmp/* && rm -rf /tmp/*
COPY en_SE.locale /tmp/en_SE.locale
RUN test ! -e /usr/share/i18n/locales/en_SE && cp /tmp/en_SE.locale /usr/share/i18n/locales/en_SE && localedef -i en_SE -f UTF-8 en_SE.UTF-8 && echo "# en_SE.UTF-8 UTF-8" >> "/etc/locale.gen" && locale-gen ${LOCALES} && update-locale "LANG=$LANG"
ENV LANG $LANG
RUN groupadd -r -g 5000 build && useradd -m -u 5000 -g 5000 -c "Build user" "build"
RUN groupadd -r -g "$UID" "$USER" && useradd -m -u "$UID" -g "$UID" -c "$FULLNAME" "$USER" && mkdir /tmp/$USER && chown "$USER:$USER" "/tmp/$USER" && chmod 0700 "/tmp/$USER"
USER $USER
EOF

FULLNAME="$(getent passwd rar | awk -F':' '{print $5}')"

podman build -t wrap-base-u20-img --label=wrap .

echo "wrap-base-u20-img" > image.info
