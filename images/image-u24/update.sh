#!/bin/bash

set -e

IMAGE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)

"$IMAGE_DIR/modify.sh" "apt-get update && apt-get dist-upgrade -y"
