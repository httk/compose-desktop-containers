#!/bin/bash

ARG=""
while [ -n "$1" -a "$1" != "--" ]; do
    ARG="$ARG $1"
    shift 1
done

echo "$ARG" > "$HOME/.local/state/gamescope-daemon/args"
sleep 2
export DISPLAY=$(cat "$HOME/.local/state/gamescope-daemon/display")

exec "$@"
