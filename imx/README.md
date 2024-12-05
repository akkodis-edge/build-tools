# Development keys
This is an instruction for creating a set of development keys with no respect for securing private keys. These keys are meant for signing during development to ensure tooling and compilers support code signing by PKCS#11.

Start of by downloading NXP code signing tool (CST) from: <https://www.nxp.com/webapp/sps/download/license.jsp?colCode=IMX_CST_TOOL_NEW&appType=file2&DOWNLOAD_ID=null>


Debian 13 preparations:

```
# Dependencies
sudo apt install softhsm2 gnutls-bin

# Softhsm2 config
mkdir -p ~/.config/softhsm2
cat << 'EOF' > ~/.config/softhsm2/softhsm2.conf
directories.tokendir = /var/lib/softhsm/tokens/
objectstore.backend = file
log.level = INFO
slots.mechanisms = ALL
EOF

# Add current user to softhsm2 group
sudo usermod -aG softhsm $(id -nu)
# Reboot for group permissions to take effect
sudo reboot

# Initialize token
softhsm2-util --init-token --slot 0 --label $(id -nu) --so-pin 654321 --pin 123456

# Ensure token is accessible
p11tool --list-mechanisms "pkcs11:token=$(id -nu)"
```

Key creation and injection into softhsm2:

```
# Extract CST and enter key directory
tar -xf tar -xf IMX_CST_TOOL_NEW.tgz

# Generate keys
cst-3.4.1/keys/hab4_pki_tree.sh" -existing-ca n -kt rsa -kl 4096 -duration 40 -num-srk 4 -srk-ca y

# Generate fuse table
cst-3.4.1/linux64/bin/srktool -h 4 -f 1 -d sha256 \
	-t SRK_1_2_3_4_table.bin \
	-e SRK_1_2_3_4_fuse.bin \
	-c "cst-3.4.1/crts/SRK1_sha256_4096_65537_v3_ca_crt.pem,cst-3.4.1/crts/SRK2_sha256_4096_65537_v3_ca_crt.pem,cst-3.4.1/crts/SRK3_sha256_4096_65537_v3_ca_crt.pem,cst-3.4.1/crts/SRK4_sha256_4096_65537_v3_ca_crt.pem"

# Store SRK table and fuse data for usage with signing tools
cp -v SRK_1_2_3_4_table.bin ~/.config/softhsm2/
cp -v SRK_1_2_3_4_fuse.bin ~/.config/softhsm2/

# Inject signing keys and certificates
# A "Enter password:" prompt will appear multiple times, enter the nxp default "test" each time.
export GNUTLS_PIN=123456
for x in {1..4}; do
	p11tool --load-certificate cst-3.4.1/crts/CSF${x}_1_sha256_4096_65537_v3_usr_crt.pem --write --label habv4_csf$x --login "pkcs11:token=$(id -nu)"
	p11tool --load-privkey cst-3.4.1/keys/CSF${x}_1_sha256_4096_65537_v3_usr_key.pem --write --label habv4_csf$x --login "pkcs11:token=$(id -nu)"
	p11tool --load-certificate cst-3.4.1/crts/IMG${x}_1_sha256_4096_65537_v3_usr_crt.pem --write --label habv4_img$x --login "pkcs11:token=$(id -nu)"
	p11tool --load-privkey cst-3.4.1/keys/IMG${x}_1_sha256_4096_65537_v3_usr_key.pem --write --label habv4_img$x --login "pkcs11:token=$(id -nu)"
done

# sign-imx.sh usage examples:
# U-boot SPL:
sign-imx.sh --table "/home/$(id -nu)/.config/softhsm2/SRK_1_2_3_4_table.bin" --csf "pkcs11:token=$(id -nu);object=habv4_csf1;type=cert;pin-value=123456" --img "pkcs11:token=$(id -nu);object=habv4_img1;type=cert;pin-value=123456" -t spl spl.img spl-signed.img
# U-boot mainline:
sign-imx.sh --table "/home/$(id -nu)/.config/softhsm2/SRK_1_2_3_4_table.bin" --csf "pkcs11:token=$(id -nu);object=habv4_csf1;type=cert;pin-value=123456" --img "pkcs11:token=$(id -nu);object=habv4_img1;type=cert;pin-value=123456" --loadaddr 0x43600000 -t fit u-boot.itb u-boot-signed.itb

```