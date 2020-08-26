#!/bin/bash
#
# Run a oe-build image as current user with access to source folder and optionally with system wide SSTATE and DOWNLOADS
#

set -e

# Parse arguments
source_dir=""
sstate_dir=""
downloads_dir=""
pass_ssh=false
while getopts "h?s:c:d:k" opt; do
    case "$opt" in
    h|\?)
        echo "Usage: $(basename $0) [OPTIONS]"
        echo
        echo "Options:"
        echo " -c      Source directory to pass into container"
        echo " -s      sstate-cache directory to pass into container"
        echo " -d      downloads directory to pass into container"
        echo
        exit 0
        ;;
    c)  source_dir="$(realpath $OPTARG)"
        ;;
    d)	downloads_dir="$(realpath $OPTARG)"
        ;;
    s)	sstate_dir="$(realpath $OPTARG)"
        ;;
    k)  pass_ssh=true
        ;;
    esac
done

cmd="docker run -it"
if [ ! -z ${source_dir} ]; then
	cmd="$cmd -v $source_dir:$source_dir"
fi
if [ ! -z ${sstate_dir} ]; then
	cmd="$cmd -v $sstate_dir:$sstate_dir"
fi
if [ ! -z ${downloads_dir} ]; then
	cmd="$cmd -v $downloads_dir:$downloads_dir"
fi
if ${pass_ssh}; then
    ssh_dir="/home/$(id -un)/.ssh"
	cmd="$cmd -v $ssh_dir:$ssh_dir"
fi
cmd="$cmd oe:$(id -un)" # add name:tag of image
echo "Running command:"
echo "$cmd"
$cmd
