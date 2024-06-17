#!/bin/sh

TMP_DIR="NONE"
cleanup() {
	if ! [ "$TMP_DIR" = "NONE" ]; then
		rm -r "$TMP_DIR" || echo "Failed removing temp dir"
		TMP_DIR="NONE"
	fi
}

die() {
	echo "$1"
	cleanup
	exit 1
}

print_usage() {
    echo "Usage: mkimage-pubkey.sh [ARGS] OUT"
    echo "Writes u-boot format public key dtb to OUT"
    echo "Mandatory arguments:"
    echo "  --object          PKCS#11 uri of signing key"
    echo "  --hint           Key label (Used as key-name-hint for matching key)"
    echo ""
    echo "Expects HSM PIN is available in environment"
    echo "variable GNUTLS_PIN."
    echo ""
}

while [ $# -gt 0 ]; do
	case $1 in
	--object)
		pkcs11_object="$2"
		shift # past argument
		shift # past value
		;;
	--hint)
		hint="$2"
		shift # past argument
		shift # past value
		;;
	-*|--*)
		print_usage
		exit 1
		;;
	*)
		if [ "x$output" = "x" ]; then
			output="$1"
		fi
		shift # past argument
		;;
  esac
done

[ "x$pkcs11_object" = "x" ] && die "Missing mandatory argument --object"
[ "x$hint" = "x" ] && die "Missing mandatory argument --hint"
[ "x$output" = "x" ] && die "Missing mandatory argument OUT"


TMP_DIR=$(mktemp -d) || die "Failed creating temp dir"


# Minimal .its file
		cat > "${TMP_DIR}/minimal.its" << EOF
/dts-v1/;

/ {
    description = "Minimal";
    #address-cells = <1>;
    images {
        kernel-1 {
            description = "Linux kernel";
            data = /incbin/("${TMP_DIR}/kernel.bin");
            type = "kernel";
            arch = "arm64";
            os = "linux";
            compression = "none";
            load = <0x40600000>;
            entry = <0x40600000>;
            hash-1 {
                algo = "sha256";
            };
        };
        fdt-1.dtb {
            description = "Flattened Device Tree blob";
            data = /incbin/("${TMP_DIR}/fdt.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            load = <0x43000000>;
            hash-1 {
                algo = "sha256";
            };
        };
	};
    configurations {
        default = "conf-default.dtb";
       	conf-default.dtb {
            description = "Test";
            compatible = "";
            kernel = "kernel-1";
            fdt = "fdt-1.dtb";
            signature-1 {
                algo = "sha256,rsa4096";
                key-name-hint = "${hint}";
            };
        };
	};
};
EOF

# Empty output .dtb
		cat > "${TMP_DIR}/empty.dts" << EOF
/dts-v1/;
/ {
};
EOF

dtc -I dts -o "${TMP_DIR}/empty.dtb" "${TMP_DIR}/empty.dts" || die "Failed generating empty.dtb"
dd if=/dev/zero of="${TMP_DIR}/kernel.bin" bs=1K count=1 || die "Failed generating kernel.bin"
dd if=/dev/zero of="${TMP_DIR}/fdt.dtb" bs=1K count=1 || die "Failed generating fdt.dtb"
MKIMAGE_SIGN_PIN="$GNUTLS_PIN" mkimage -N pkcs11 -f "${TMP_DIR}/minimal.its" -K "${TMP_DIR}/empty.dtb" \
	 -k "${pkcs11_object#pkcs11:}" -r "${TMP_DIR}/minimal.fit" || die "Failed signing"

cp -v "${TMP_DIR}/empty.dtb" "$output"

cleanup

exit 0
