#!/bin/bash
set -euo pipefail
echo "Configuring rootless Docker Swarm..."
dockerd-rootless-setuptool.sh install
systemctl --user enable docker
systemctl --user start docker
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
echo "Rootless Swarm initialized."