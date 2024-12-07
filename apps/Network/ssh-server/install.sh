#!/bin/bash

set -e

mkdir -p home/.ssh/hostkeys
mkdir -p files
chmod og-rwx home/.ssh
if [ ! -e home/.ssh/hostkeys/ssh_host_ed25519_key ]; then
    ssh-keygen -q -N "" -t ed25519 -f home/.ssh/hostkeys/ssh_host_ed25519_key
fi
if [ ! -e files/ssh_host_ed25519_key ]; then
    ssh-keygen -q -N "" -t ed25519 -f files/ssh_client_ed25519_key
fi
cp files/ssh_client_ed25519_key.pub home/.ssh/authorized_keys
