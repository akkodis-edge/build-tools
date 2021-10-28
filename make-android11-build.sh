#!/bin/bash
#
# Build a docker image running as current user. 
# Container will be tagger android11:[USERNAME]
#

set -e
USER="$(id -un)"
docker build -t android11:${USER} --build-arg "USERNAME=${USER}" --build-arg "UID=$(id -u)" --build-arg "GID=$(id -g)" - < "$(dirname $0)"/android11-build.docker
echo 
echo "Finished image build: android11:${USER}"