#!/bin/bash

set -e

LATESTURL=$(curl -s 'https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest' | jq --raw-output '.assets[] | .browser_download_url' | grep '\.tar\.gz$')
LATESTFILENAME="${LATESTURL##*/}"

mkdir -p files opt/proton
if [ ! -e "files/$LATESTFILENAME" ]; then
    curl -L -o "files/$LATESTFILENAME" "$LATESTURL"
fi

cd opt/proton
tar -zxvf "../../files/$LATESTFILENAME"

echo "Proton install in opt"
