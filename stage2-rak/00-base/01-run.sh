#!/bin/bash -e

# Cloud-Init for trixie (filesystem expansion on first boot)
install -v -m 644 files/meta-data "${ROOTFS_DIR}/boot/firmware/meta-data"
install -v -m 644 files/user-data "${ROOTFS_DIR}/boot/firmware/user-data"
# network-config intentionally not installed (conflicts with NetworkManager)

# Add custom firstboot script
#install -m 755 files/firstboot-rak "${ROOTFS_DIR}/usr/bin/"
#install -d "${ROOTFS_DIR}/usr/share/firstboot.d/"
#install -m 755 files/firstboot.d/* "${ROOTFS_DIR}/usr/share/firstboot.d/"
#sed -i "s|main$|main\nfirstboot-rak\n|" "${ROOTFS_DIR}/usr/lib/raspberrypi-sys-mods/firstboot"

# Build overlays
dtc -I dts -O dtb files/rak7391.dts -o files/rak7391.dtbo
install -m 755 files/rak7391.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/"

# Update config.txt
install -m 755 files/config.txt "${ROOTFS_DIR}/boot/firmware/"

# Add carrier board detection (fills in the RAK BOARD block in config.txt)
install -m 755 files/rak-board-detect "${ROOTFS_DIR}/usr/local/bin/"
install -m 644 files/rak-board-detect.service "${ROOTFS_DIR}/etc/systemd/system/"
on_chroot << EOF
systemctl enable rak-board-detect
EOF

# Enable SSH
on_chroot << EOF
sudo raspi-config nonint do_ssh 0
EOF

# Enable I2C
on_chroot << EOF
echo "i2c-dev" >> /etc/modules
sudo raspi-config nonint do_i2c 0
EOF

# Enable SPI
on_chroot << EOF
sudo raspi-config nonint do_spi 0
EOF

# Force user to change password after first login
on_chroot << EOF
passwd -e $FIRST_USER_NAME
echo "$FIRST_USER_NAME ALL=(ALL) PASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd
EOF

# Configure Network Manager
on_chroot << EOF
sed -i "s/managed=false/managed=true/g" "/etc/NetworkManager/NetworkManager.conf"
EOF

# Do not hold the boot open waiting for the network to come all the way up.
# NetworkManager-wait-online is the only unit ordered before
# network-online.target, and docker pulls that target into multi-user.target, so
# the whole boot serialises behind ethernet link negotiation, DHCP and IPv6
# settling -- around seven seconds on this hardware, most of it the PHY
# autonegotiating. Nothing here needs a routable address that early: dockerd
# builds its own bridge and firewall rules, and the cloud-init modules that do
# want the network are ordered after multi-user.target anyway. Containers that
# need connectivity at startup have to handle their own retries regardless.
on_chroot << EOF
systemctl disable NetworkManager-wait-online.service
EOF

# Enable Wifi
on_chroot << EOF
raspi-config nonint do_wifi_country GB
EOF

# Update os-release file
#
# Vulnerability scanners and SBOM tools identify the system from the standard
# fields (ID, VERSION_ID, VERSION_CODENAME). With ID=rakpios and a VERSION_ID of
# "rakpios-x.y.z-arm64" they took the image for an unknown distribution, matched
# no vulnerabilities at all, and wrote package URLs nothing could resolve. So
# those fields carry Debian's identity, and RAKPiOS names itself in NAME,
# PRETTY_NAME and IMAGE_ID/IMAGE_VERSION, the fields freedesktop.org defines for
# an image built on top of a distribution. PRETTY_NAME is what the MOTD shows;
# the OLED panel reads IMAGE_VERSION.
#
# Mind the two VERSIONs. The build variable ${VERSION} (from config_rak, through
# build.sh) is the RAKPiOS release and goes into IMAGE_VERSION and PRETTY_NAME.
# The file's own VERSION= field is the Debian version. Swapping them puts the
# RAKPiOS release back into a field scanners read, which the checks below catch.
#
# COMMIT_SHA and COMMIT_DATE come from the host (build-docker.sh, build.sh):
# git can't run inside the build container.
#
# The file belongs to base-files and is not a conffile, so every base-files
# upgrade would put Debian's copy back and wipe the RAKPiOS identity. Each Debian
# point release brings one, and the automatic updates install it. A local
# diversion makes dpkg write its copy to os-release.debian instead. Copy first,
# then divert without renaming, so the file never goes missing in between:
# base-files is Essential, and dpkg warns against renaming its files away. The
# guard keeps a second run from copying our file over Debian's.
on_chroot << EOF
if ! dpkg-divert --list /usr/lib/os-release | grep -q .; then
    cp -a /usr/lib/os-release /usr/lib/os-release.debian
    dpkg-divert --local --no-rename --divert /usr/lib/os-release.debian --add /usr/lib/os-release
fi
EOF
DEBIAN_MAJOR=$(cut -d. -f1 "${ROOTFS_DIR}/etc/debian_version")
cat > "${ROOTFS_DIR}/usr/lib/os-release" << EOL
PRETTY_NAME="${NAME} ${VERSION} (${RELEASE})"
NAME="${NAME}"
VERSION="${DEBIAN_MAJOR} (${RELEASE})"
VERSION_ID="${DEBIAN_MAJOR}"
VERSION_CODENAME="${RELEASE}"
ID=debian
IMAGE_ID="${NAME,,}"
IMAGE_VERSION="${VERSION}"
BUILD_ID="${IMG_DATE}"
VARIANT="${ARCH}"
HOME_URL="http://www.rakwireless.com/"
SUPPORT_URL="${PI_GEN_REPO}"
BUG_REPORT_URL="${PI_GEN_REPO}/issues"
COMMIT_SHA="${GIT_HASH:0:7}"
COMMIT_DATE="${GIT_COMMIT_DATE}"
IMAGE_DATE="$(date +%Y-%m-%d)"
EOL
echo "os-release written:"
cat "${ROOTFS_DIR}/usr/lib/os-release"

# Check the file the way its readers see it: source it in a subshell. A quoting
# mistake then fails here too, and the build's own NAME and VERSION stay intact.
# 1.0.0 shipped an empty COMMIT_SHA because nothing checked; this is the check.
if ! (
    expected_name="${NAME}"
    expected_release="${VERSION}"
    expected_codename="${RELEASE}"
    expected_major="${DEBIAN_MAJOR}"
    fields="PRETTY_NAME NAME VERSION VERSION_ID VERSION_CODENAME ID IMAGE_ID IMAGE_VERSION BUILD_ID VARIANT HOME_URL SUPPORT_URL BUG_REPORT_URL COMMIT_SHA COMMIT_DATE IMAGE_DATE"
    # A field missing from the file must not pass because the build happens to
    # have a variable of the same name (NAME, VERSION), so clear them all first.
    # shellcheck disable=SC2086 # word splitting of the field list is intended
    unset ${fields} ID_LIKE
    # shellcheck source=/dev/null
    . "${ROOTFS_DIR}/usr/lib/os-release" || { echo "os-release: the file can't be sourced"; exit 1; }
    ok=1
    fail() { echo "os-release: $*"; ok=0; }
    for field in ${fields}; do
        [ -n "${!field}" ] || fail "${field} is empty or missing"
    done
    [[ "${expected_major}" =~ ^[0-9]+$ ]] || fail "/etc/debian_version gives '${expected_major}', not a Debian major"
    [ "${ID}" = "debian" ] || fail "ID is '${ID}', not 'debian'"
    [ "${VERSION_ID}" = "${expected_major}" ] || fail "VERSION_ID is '${VERSION_ID}', not the Debian major '${expected_major}'"
    [ "${VERSION_CODENAME}" = "${expected_codename}" ] || fail "VERSION_CODENAME is '${VERSION_CODENAME}', not '${expected_codename}'"
    [ "${VERSION}" = "${expected_major} (${expected_codename})" ] || fail "VERSION is '${VERSION}', not the Debian version '${expected_major} (${expected_codename})'"
    [ "${NAME}" = "${expected_name}" ] || fail "NAME is '${NAME}', not '${expected_name}'"
    [ "${PRETTY_NAME}" = "${expected_name} ${expected_release} (${expected_codename})" ] || fail "PRETTY_NAME is '${PRETTY_NAME}'"
    [ "${IMAGE_ID}" = "${expected_name,,}" ] || fail "IMAGE_ID is '${IMAGE_ID}', not '${expected_name,,}'"
    [ "${IMAGE_VERSION}" = "${expected_release}" ] || fail "IMAGE_VERSION is '${IMAGE_VERSION}', not the RAKPiOS release '${expected_release}'"
    [[ "${COMMIT_SHA}" =~ ^[0-9a-f]{7}$ ]] || fail "COMMIT_SHA '${COMMIT_SHA}' is not a 7-character commit hash"
    [[ "${COMMIT_DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "COMMIT_DATE '${COMMIT_DATE}' is not YYYY-MM-DD"
    [ -z "${ID_LIKE+set}" ] || fail "ID_LIKE is set; it is redundant with ID=debian"
    # The diversions database holds three lines per entry: from, to, package
    # (":" for a local diversion)
    diverted=$(awk 'NR % 3 == 1 && $0 == "/usr/lib/os-release" { getline to; getline pkg; print to, pkg }' "${ROOTFS_DIR}/var/lib/dpkg/diversions")
    [ "${diverted}" = "/usr/lib/os-release.debian :" ] || fail "no local diversion of /usr/lib/os-release, so the next base-files upgrade would overwrite it"
    # Upgrades keep writing Debian's own copy to os-release.debian. It has
    # ID=debian but none of RAKPiOS's fields. Finding ours there means the
    # rootfs wasn't fresh: a CONTINUE build without CLEAN=1 reruns this script
    # on its own earlier output, and the copy above then saved our file.
    debian_copy="${ROOTFS_DIR}/usr/lib/os-release.debian"
    if ! grep -qx 'ID=debian' "${debian_copy}" 2>/dev/null || grep -q '^IMAGE_ID=' "${debian_copy}" || grep -qx "NAME=\"${expected_name}\"" "${debian_copy}"; then
        fail "/usr/lib/os-release.debian is missing or isn't Debian's file (in a CONTINUE build, set CLEAN=1)"
    fi
    [ "${ok}" = 1 ]
); then
    echo "os-release: checks failed, stopping the build" >&2
    exit 1
fi
echo "os-release: all checks passed"

