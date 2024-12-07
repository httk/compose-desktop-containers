#!/bin/bash

podman kill $(podman ps --filter label=wrap -q)
podman rm $(podman ps --all --filter label=wrap -q)
buildah rm --all
podman rmi $(podman images --filter label=wrap -q)

# Could also do: podman system prune
# Or even: podman system reset
