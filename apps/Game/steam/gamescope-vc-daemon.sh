#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: gamescope-vc-daemon.sh <syncronization home directory>"
    exit 1
fi

GAMESCOPE=~/Containers/images/fat-u24/outputs/install/usr/local/bin/gamescope

HOMEDIR="$1"
SYNCDIR="${HOMEDIR}/.local/state/gamescope-daemon"
mkdir -p "${SYNCDIR}"
touch "${SYNCDIR}/args"

ARGS=""
while [ "0" == "0" ]; do
    DXVK_HDR=0 ENABLE_GAMESCOPE_WSI=0 "$GAMESCOPE" ${ARGS} -- bash -c "echo \"\${DISPLAY}\" > \"${SYNCDIR}/display\" && ln -sf \"X\${DISPLAY:1}\" \"/tmp/.X11-unix/X42\" && sleep infinity" &
    # -- bash -c "echo \"\${DISPLAY}\" > \"${SYNCDIR}/display\" && ln -sf \"X\${DISPLAY:1}\" \"/tmp/.X11-unix/X42\" && xterm" &
    GSPID="$!"

    inotifywait -e modify "${SYNCDIR}/args"

    # Somewhat gracefully kill the old gamescope process
    sleep 5 &
    kill "$GSPID" || true
    wait -n

    if kill -0 "$GSPID" 2>/dev/null; then
	kill -9 "$GSPID"
    fi

    PARAMS=$(cat "${SYNCDIR}/args")

    # We need to sanitize gamescope args sent to us, otherwise a process inside the container with access to the args file could use this to escape
    ARGS=$(printf "%s\n" "$PARAMS" | awk '
    {
        for (i=1; i<=NF; i++) {
            processString($i)
        }
    }

    function sanitize_string(str) {
      if (str ~ /^[a-z-]+$/) {
        return str
      } else {
        return ""
      }
    }

    function sanitize_float(str) {
      if (str ~ /^-?[0-9]+(\.[0-9]+)?$/) {
        return str
      } else {
        return ""
      }
    }

    function processString(val) {
          if(val == "-H" || val == "--output-height") {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-H",a)}};
          if(val == "-W" || val == "--output-width" ) {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-W",a)}};
          if(val == "-h" || val == "--nested-height" ) {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-h",a)}};
          if(val == "-w" || val == "--nested-width" ) {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-w",a)}};
          if(val == "-r" || val == "--nested-refresh") {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-r",a)}};
          if(val == "-m" || val == "--max-scale" ) {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-m",a)}};
          if(val == "-S" || val == "--scaler" ) {i=i+1; a=sanitize_string($i); if (a != "") {printf("%s %s ","-S",a)}};
          if(val == "-F" || val == "--filter" ) {i=i+1; a=sanitize_string($i); if (a != "") {printf("%s %s ","-F",a)}};
          if(val == "--sharpness" || val == "--fsr-sharpness" ) {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","--sharpness",a)}};
          if(val == "--expose-wayland") {printf("%s","--expose-wayland")};
          if(val == "--rt") {printf("%s","--rt")};
          if(val == "-C" || val == "--hide-cursor-delay") {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-C",a)}};
          if(val == "--prefer-vk-device") {printf("%s","--prefer-vk-device")};
          if(val == "--force-orientation" ) {i=i+1; a=sanitize_string($i); if (a != "") {printf("%s %s ","--force-orientation",a)}};
          if(val == "--force-windows-fullscreen") {printf("%s","--force-windows-fullscreen")};
          if(val == "--cursor-scale-height") {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","--cursor-scale-height",a)}};
          if(val == "--hdr-enabled") {printf("%s","--hdr-enabled")};
          if(val == "--sdr-gamut-wideness" ) {i=i+1; a=sanitize_float($i); if (a != "") {printf("%s %.6f ","--sdr-gamut-wideness",a)}};
          if(val == "--hdr-sdr-content-nits" ) {i=i+1; a=sanitize_float($i); if (a != "") {printf("%s %.6f ","--hdr-sdr-content-nits",a)}};
	  if(val == "--hdr-itm-enable") {printf("%s","--hdr-itm-enable")};
          if(val == "--hdr-itm-sdr-nits") {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","--hdr-itm-sdr-nits",a)}};
          if(val == "--hdr-itm-target-nits") {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","--hdr-itm-target-nits",a)}};
          if(val == "--framerate-limit") {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","--framerate-limit",a)}};
          if(val == "-O" || val == "--prefer-output") {i=i+1; a=sanitize_string($i); if (a != "") {printf("%s %s ","-O",a)}};
          if(val == "--default-touch-mode" ) {i=i+1; a=int($i); if (a > 0 && a < 100000) {printf("%s %d ","-default-touch-mode",a)}};
          if(val == "--generate-drm-mode" ) {i=i+1; a=sanitize_string($i); if (a != "") {printf("%s %s ","--generate-drm-mode",a)}};
          if(val == "--immediate-flips") {printf("%s","--immediate-flips")};
          if(val == "--adaptive-sync") {printf("%s","--adaptive-sync")};
    }
    ')

done
