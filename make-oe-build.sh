#!/bin/bash
#
# Build a docker image running as current user. 
# Container will be tagger oe:[USERNAME]
#

set -e
USER="$(id -un)"
docker build -t oe:${USER} --build-arg "USERNAME=${USER}" --build-arg "UID=$(id -u)" --build-arg "GID=$(id -g)" - < oe-build.docker
echo 
echo "Finished image build: oe:${USER}"