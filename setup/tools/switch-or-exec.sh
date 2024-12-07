#!/bin/bash

APP="$1"
shift 1

wmctrl -x -a "$APP" || exec "$@"
