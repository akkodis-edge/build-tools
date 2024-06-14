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
working_directory=""
p11_server=false
bb_env_passthrough_additions=""
while getopts "h?s:c:d:kpw:" opt; do
    case "$opt" in
    h|\?)
        echo "Usage: $(basename $0) [OPTIONS]"
        echo
        echo "Options:"
        echo " -c      Source directory to pass into container"
        echo " -s      sstate-cache directory to pass into container"
        echo " -d      downloads directory to pass into container"
        echo " -w      container working directory"
        echo " -p      p11-kit server socket export"
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
    w)  working_directory="$(realpath $OPTARG)"
        ;;
    p)  p11_server=true
    esac
done

cmd="docker run -it"
if [ ! -z ${source_dir} ]; then
	cmd="$cmd -v $source_dir:$source_dir"
fi
if [ ! -z ${sstate_dir} ]; then
	export SSTATE_DIR="${sstate_dir}"
	cmd="$cmd -v $sstate_dir:$sstate_dir -e SSTATE_DIR"
	bb_env_passthrough_additions="${bb_env_passthrough_additions} SSTATE_DIR"
fi
if [ ! -z ${downloads_dir} ]; then
	export DL_DIR="${downloads_dir}"
	cmd="$cmd -v $downloads_dir:$downloads_dir -e DL_DIR"
	bb_env_passthrough_additions="${bb_env_passthrough_additions} DL_DIR"
fi
if ${p11_server}; then
    p11_dir="/run/user/$(id -u)/p11-kit"
	cmd="$cmd -v $p11_dir:$p11_dir -e P11_KIT_SERVER_PID -e P11_KIT_SERVER_ADDRESS"
	bb_env_passthrough_additions="${bb_env_passthrough_additions} P11_KIT_SERVER_PID P11_KIT_SERVER_ADDRESS"
fi
if [ ! -z "${bb_env_passthrough_additions}" ]; then
	export BB_ENV_PASSTHROUGH_ADDITIONS="${bb_env_passthrough_additions}"
	cmd="$cmd -e BB_ENV_PASSTHROUGH_ADDITIONS"
fi 
if ${pass_ssh}; then
    ssh_dir="/home/$(id -un)/.ssh"
	cmd="$cmd -v $ssh_dir:$ssh_dir"
fi
if [ ! -z ${working_directory} ]; then
	cmd="$cmd -w $working_directory"
fi

cmd="$cmd oe-kirkstone:$(id -un)" # add name:tag of image
echo "Running command:"
echo "$cmd"
$cmd
