#!/bin/sh

die() {
	echo $1
	exit 1
}

# Parse arguments
recursive="false"

OPTIND=1
while getopts "h?ra" opt; do
    case "$opt" in
    h|\?)
        echo "Usage: $(basename $0) [OPTIONS] PATH"
        echo 
        echo "Data Respons Solutions deployment tool"
        echo 
        echo "Deployables are known by the caller and managed as"
        echo "commandline arguments while the remote is unknown and"
        echo "managed by environment variables."
        echo
        echo "Options:"
        echo " -r      Recursive mode, deploy directory trees"
        echo
        echo "Variables:"
        echo " DRS_DEPLOY_PATH: Path on remote"
        echo " DRS_DEPLOY_METHOD: Deployment method"
        echo "   \"ftp\""
        echo "      This method shouldn't really be used as deployables are transmitted"
        echo "      unencrypted and credentials are exposed in plaint text."
        echo "      Depends: ncftpput"
        echo "      Options:"
        echo "         DRS_FTP_URL: Server URL (Mandatory)"
        echo "         DRS_FTP_USER: Username (Mandatory)"
        echo "         DRS_FTP_PASSWORD: Password (mandatory)"
        echo 
        echo "   \"sftp\""
        echo "      Secure ftp. Respects  ~/.ssh/config."
        echo "      Depends: sftp"
        echo "      Options:"
        echo "         DRS_SFTP_URL: Server url (Mandatory)"
        echo "         DRS_SFTP_USER: Username"
        echo "         DRS_SFTP_KEY: Path to privat key"
        echo 
        exit 0
        ;;
    r)  recursive="true"
        ;;
    esac
done
shift $((OPTIND-1))

if [ "x$1" = "x" ]; then
	echo "Missing mandaotry argument PATH"
	exit 1
fi
path="$1"

# DRS_DEPLOY_PATH = Path to deploy files on remote 
if [ "x$DRS_DEPLOY_PATH" = "x" ]; then
	echo "Missing variable: DRS_DEPLOY_PATH"
	exit 1
fi

echo "Deploying by \"$DRS_DEPLOY_METHOD\" to \"$DRS_DEPLOY_PATH\" -- \"$path\""
res=0
#
# DRS_DEPLOY_METHOD = ftp
#
if [ "$DRS_DEPLOY_METHOD" = "ftp" ]; then
	if [ "x$DRS_FTP_URL" = "x" ] ||
		[ "x$DRS_FTP_USER" = "x" ] || 
		[ "x$DRS_FTP_PASSWORD" = "x" ]; then
		echo "Missing parameter for method $DRS_DEPLOY_METHOD"
		echo "Mandatory:"
		echo "  DRS_FTP_URL"
		echo "  DRS_FTP_USER"
		echo "  DRS_FTP_PASSWORD"
		exit 1
	fi
		
	cmd="ncftpput"
	if [ "$recursive" = "true" ]; then
		cmd="$cmd -R"
	fi
	$cmd -u "$DRS_FTP_USER" -p "$DRS_FTP_PASSWORD" "$DRS_FTP_URL" "${DRS_DEPLOYT_PATH}" "$path"
	res=$?
#
# DRS_DEPLOY_METHOD = sftp
#
elif [ "$DRS_DEPLOY_METHOD" = "sftp" ]; then
	if [ "x$DRS_SFTP_URL" = "x" ]; then
		echo "Missing parameter for method $DRS_DEPLOY_METHOD"
		echo "Mandatory:"
		echo "  DRS_SFTP_URL"
		exit 1
	fi
	
	batchfile=$(mktemp) || die "Failed creating tempfile"
	echo "-mkdir /${DRS_DEPLOY_PATH}" > $batchfile
	echo "put $path $DRS_DEPLOY_PATH" >> $batchfile
	echo "quit" >> $batchfile
	
	# Pass in user and key
	if [ "x$DRS_SFTP_USER" != "x" ] && [ "x$DRS_SFTP_KEY" != "x" ]; then
		sftp -oIdentityFile="$DRS_SFTP_KEY" -b $batchfile "$DRS_SFTP_USER"@"$DRS_SFTP_URL"
		res=$?	
	# pass in user, key from ssh config
	elif [ "x$DRS_SFTP_USER" != "x" ]; then
		sftp -b $batchfile "$DRS_SFTP_USER"@"$DRS_SFTP_URL"
		res=$?
	# user and key form ssh config
	else 
		sftp -b $batchfile "$DRS_SFTP_URL"
		res=$?
	fi
	rm $batchfile
else
	echo "Unknown deploy method"
	exit 1
fi

if [ $res -ne 0 ]; then
	echo "Failed deploy [$res]"
	exit 1
fi

exit 0
