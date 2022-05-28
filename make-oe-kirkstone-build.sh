#!/bin/bash
#
# Build a docker image running as current user. 
# Container will be tagger oe-kirkstone:[USERNAME]
#

set -e
USER="$(id -un)"
docker build -t oe-kirkstone:${USER} --build-arg "USERNAME=${USER}" --build-arg "UID=$(id -u)" --build-arg "GID=$(id -g)" - < "$(dirname $0)"/oe-kirkstone-build.docker
echo 
echo "Finished image build: oe-kirkstone:${USER}"