#!/bin/sh

# Size of CSF
csf_size="0x2000"
TMP_DIR="NONE"
debug=0

cleanup() {
	if ! [ ${TMP_DIR} = "NONE" ]; then
		rm -r ${TMP_DIR} || echo "Failed removing temp dir"
		TMP_DIR="NONE"
	fi
}

die() {
	echo "$1"
	cleanup
	exit 1
}

print_usage() {
    echo "Usage: sign.sh [ARGS] ARTIFACT OUT"
    echo "Mandatory arguments:"
    echo "  -t,--type         Artifact type"
    echo "                      - spl"
    echo "                      - fit"
    echo "                      - platform"
    echo "  --table           Path to SRK_table.bin"
    echo "  --csf             PKCS#11 URL for CSFX key"
    echo "  --img             PKCS#11 URL for IMGX key"
    echo ""
    echo "Optional arguments:"
    echo "  --debug           Show debug output"
}

while [ $# -gt 0 ]; do
	case $1 in
	-t|--type)
		type="$2"
		shift # past argument
		shift # past value
		;;
	--table)
		srk_table="$2"
		shift # past argument
		shift # past value
		;;
	--csf)
		csf_pkcs11="$2"
		shift # past argument
		shift # past value
		;;
	--img)
		img_pkcs11="$2"
		shift # past argument
		shift # past value
		;;
	--debug)
		debug=1
		shift # past argument
		;;
	-*|--*)
		print_usage
		exit 1
		;;
	*)
		if [ "x$artifact" = "x" ]; then
			artifact="$1"
		elif [ "x$output" = "x" ]; then
			output="$1"
		fi
		shift # past argument
		;;
  esac
done

[ "x$artifact" = "x" ] && die "Missing mandatory argument ARTIFACT"
[ "x$output" = "x" ] && die "Missing mandatory argument OUT"
[ "x$type" = "x" ] && die "Missing mandatory argument --type"
[ "x$csf_pkcs11" = "x" ] && die "Missing mandatory argument --csf"
[ "x$srk_table" = "x" ] && die "Missing mandatory argument --table"
[ "x$img_pkcs11" = "x" ] && die "Missing mandatory argument --img"

TMP_DIR=$(mktemp -d) || die "Failed creating temp dir"
base="$(dirname $(realpath -s $0))" || die "Failed getting script dir"
build="${TMP_DIR}"
artifact_size="$(stat -tc %s ${artifact})" || die "Failed getting ARTIFACT size"
artifact_path="$(realpath -s ${artifact})" || die "Failed getting ARTIFACT path"
artifact_name="$(basename ${artifact})" || die "Failed getting ARTIFACT basename"
output_path="$(realpath -s ${output})" || die "Failed getting OUT path"

case "$type" in
	platform)
		platform_ivt_offset="1024"
		platform_csf_offset="1056" # 0x420
		platform_ddr_offset="0x2420"
		platform_ddr_size="$(( ${artifact_size} - ${platform_ddr_offset} ))"
		platform_ddr_hex="$(printf '0x%08x' ${platform_ddr_size})"
		cat > "${build}/csf_platform.txt" << EOF
[Header]
  Version = 4.5
  Hash Algorithm = sha256
  Engine = CAAM
  Engine Configuration = 0
  Certificate Format = X509
  Signature Format = CMS

[Install SRK]
  File = "${srk_table}"
  Source index = 0

[Install CSFK]
  File = "${csf_pkcs11}"

[Authenticate CSF]

[Install Key]
  Verification index = 0
  Target Index = 2
  File = "${img_pkcs11}"

[Authenticate Data]
  Verification index = 2
  # 0x961000: platform header, 1K (0x400)
  # 0x961400: IVT 32B (0x20)
  # 0x961420: CSF 8K (0x2000)
  # 0x963420: DDR blob
  Blocks = 0x961000 0x0 0x420 "${build}/${artifact_name}", \\
           0x963420 0x2420 ${platform_ddr_size} "${build}/${artifact_name}"
EOF
		cp -v "$artifact_path" "${build}/${artifact_name}" || die "Failed getting artifact"
		echo "0xd1002041 0x00109600 0x00000000 0x00000000 0x00000000 0x00149600 0x20149600 0x00000000" | xxd -r -p > "${build}/platform_ivt.bin" || die "Failed generating ivt"
		[ "$debug" = 1 ] && echo "IVT binary:"
		[ "$debug" = 1 ] && xxd -g 4 "${build}/platform_ivt.bin"
		[ "$debug" = 1 ] && echo "CST input file:"
		[ "$debug" = 1 ] && cat "${build}/csf_platform.txt"
		dd if="${build}/platform_ivt.bin" of="${build}/${artifact_name}" bs=1 seek=${platform_ivt_offset} conv=notrunc || die "Failed writing ivt"
		cst -b pkcs11 -i "${build}/csf_platform.txt" -o "${build}/csf_platform.bin" || die "Failed generating csf"
		# Write csf to end of image
		dd conv=notrunc seek="$platform_csf_offset" bs=1 if="${build}/csf_platform.bin" of="${build}/${artifact_name}" || die "Failed writing CSF"
		;;
	spl)
		[ "$debug" = 1 ] && echo "IVT binary:"
		[ "$debug" = 1 ] && xxd -g 4 -l 32 "$artifact"
		spl_csf_offset="$(xxd -s 24 -l 4 -e ${artifact} | cut -d ' ' -f 2 | sed 's@^@0x@')" || die "Failed getting SPL csf offset"
		spl_bin_offset="$(xxd -s 4 -l 4 -e ${artifact} | cut -d ' ' -f 2 | sed 's@^@0x@')" || die "Failed getting SPL bin offset"
		spl_dd_offset="$((${spl_csf_offset} - ${spl_bin_offset} + 0x40))" || die "Failed getting SPL dd offset"
		size="$(( ${artifact_size} - ${csf_size} ))"
		size_hex="$(printf '0x%08x' ${size})"
		cat > "${build}/csf_spl.txt" << EOF
[Header]
  Version = 4.5
  Hash Algorithm = sha256
  Engine = CAAM
  Engine Configuration = 0
  Certificate Format = X509
  Signature Format = CMS

[Install SRK]
  File = "${srk_table}"
  Source index = 0

[Install CSFK]
  File = "${csf_pkcs11}"

[Authenticate CSF]

[Unlock]
  Engine = CAAM
  Features = MID

[Install Key]
  Verification index = 0
  Target Index = 2
  File = "${img_pkcs11}"

[Authenticate Data]
  Verification index = 2
  Blocks = 0x911fc0 0x0 ${size_hex} "${build}/${artifact_name}"
EOF
		[ "$debug" = 1 ] && echo "CST input file:"
		[ "$debug" = 1 ] && cat "${build}/csf_spl.txt"
		cp -v "$artifact_path" "${build}/${artifact_name}" || die "Failed getting artifact"
		cst -b pkcs11 -i "${build}/csf_spl.txt" -o "${build}/csf_spl.bin" || die "Failed generating csf"
		# Write csf to end of image
		dd conv=notrunc seek="$spl_dd_offset" bs=1 if="${build}/csf_spl.bin" of="${build}/${artifact_name}" || die "Failed writing CSF"
		;;
	fit)
		# Fit is loaded to base
		fit_block_base="0x43600000" # CONFIG_SPL_LOAD_FIT_ADDRESS (0x43600000)
		fit_block_size="$(printf '0x%x' $(( ${artifact_size} + 0x20 )))" || die "Failed calculating total size"
		cat > "${build}/csf_fit.txt" << EOF
[Header]
  Version = 4.5
  Hash Algorithm = sha256
  Engine = CAAM
  Engine Configuration = 0
  Certificate Format = X509
  Signature Format = CMS

[Install SRK]
  File = "${srk_table}"
  Source index = 0

[Install CSFK]
  File = "${csf_pkcs11}"

[Authenticate CSF]

[Install Key]
  Verification index = 0
  Target Index = 2
  File = "${img_pkcs11}"

[Authenticate Data]
  Verification index = 2
  Blocks = 0x43600000 0x0 ${fit_block_size} "${build}/${artifact_name}"
EOF
		# Make IVT -- big endian fields
		# IVT -- big endian
		ivt_ptr_base=$(printf "%08x" ${fit_block_base} | sed "s@\(..\)\(..\)\(..\)\(..\)@0x\4\3\2\1@")
		ivt_block_base=$(printf "%08x" $(( ${fit_block_base} + ${fit_block_size} - 0x20 )) | sed "s@\(..\)\(..\)\(..\)\(..\)@0x\4\3\2\1@")
		csf_block_base=$(printf "%08x" $(( ${fit_block_base} + ${fit_block_size} )) | sed "s@\(..\)\(..\)\(..\)\(..\)@0x\4\3\2\1@")
		echo "0xd1002041 ${ivt_ptr_base} 0x00000000 0x00000000 0x00000000 ${ivt_block_base} ${csf_block_base} 0x00000000" | xxd -r -p > "${build}/fit_ivt.bin" || die "Failed generating ivt"
		[ "$debug" = 1 ] && echo "IVT binary:"
		[ "$debug" = 1 ] && xxd -g 4 "${build}/fit_ivt.bin"
		[ "$debug" = 1 ] && echo "CST input file:"
		[ "$debug" = 1 ] && cat "${build}/csf_fit.txt"
		# Get artifact -- expect size is 4096 aligned
		cp -v "$artifact_path" "${build}/${artifact_name}" || die "Failed getting artifact"
		# Append IVT 
		cat "${build}/fit_ivt.bin" >> "${build}/${artifact_name}" || die "Failed assembling artifact"
		# Sign
		cst -b pkcs11 -i "${build}/csf_fit.txt" -o "${build}/csf_fit.bin" || die "Failed generating csf"
		# Pad CSF to CONFIG_CSF_SIZE ($csf_size)
		dd if=/dev/null of="${build}/csf_fit.bin" bs=1 seek=$((csf_size)) count=0 || die "Failed padding CSF"
		# Append CSF
		cat "${build}/csf_fit.bin" >> "${build}/${artifact_name}" || die "Failed assembling artifact"
		;;
	*)
		echo "Invalid type $type"
		exit 1
		;;
esac

cp "${build}/${artifact_name}" "$output_path" || die "Failed writing OUT"

cleanup

exit 0
