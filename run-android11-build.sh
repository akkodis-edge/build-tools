#!/bin/bash
#
# Run a android11-build image as current user with access to source folder and optionally with system wide CCACHE
#

set -e

# Parse arguments
source_dir=""
ccache_dir=""
pass_ssh=false
working_directory=""
while getopts "h?s:c:kw:" opt; do
    case "$opt" in
    h|\?)
        echo "Usage: $(basename $0) [OPTIONS]"
        echo
        echo "Options:"
        echo " -c      Source directory to pass into container"
        echo " -s      ccache directory to pass into container"
        echo " -w      container working directory"
        echo " -k      Pass in  ~/.ssh directory"
        echo
        exit 0
        ;;
    c)  source_dir="$(realpath $OPTARG)"
        ;;
    s)	ccache_dir="$(realpath $OPTARG)"
        ;;
    k)  pass_ssh=true
        ;;
    w)  working_directory="$(realpath $OPTARG)"
        ;;
    esac
done

cmd="docker run -it"
if [ ! -z ${source_dir} ]; then
	cmd="$cmd -v $source_dir:$source_dir"
fi
if [ ! -z ${ccache_dir} ]; then
	export CCACHE_DIR="${ccache_dir}"
	export USE_CCACHE=1
	cmd="$cmd -v $ccache_dir:$ccache_dir -e CCACHE_DIR -e USE_CCACHE"
fi
if ${pass_ssh}; then
    ssh_dir="/home/$(id -un)/.ssh"
	cmd="$cmd -v $ssh_dir:$ssh_dir"
fi
if [ ! -z ${working_directory} ]; then
	cmd="$cmd -w $working_directory"
fi

cmd="$cmd android11:$(id -un)" # add name:tag of image
echo "Running command:"
echo "$cmd"
$cmd
