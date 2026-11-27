#!/bin/bash
#
# tools/sbom.sh <image.img.xz>
#
# Writes the CycloneDX 1.6 SBOM of a RAKPiOS image next to it:
# <image>.cdx.json and <image>.cdx.json.sha256. It is made from the image file
# itself, so it describes exactly what ships. The file is only written if it
# passes the CycloneDX schema and the checks below.
#
# Needs curl, xz, sfdisk, dd, debugfs (e2fsprogs), jq, sha256sum and tar, plus
# about 3 GB of free space next to the image (or in $SBOM_WORKDIR) while it
# runs. No root: the root partition is read with debugfs, not mounted.
#
# What the SBOM can't see: RAK's tools installed outside apt (oled,
# rakpios-cli, mioty-cli, the hardware test suite) have no package metadata,
# so they aren't in it as such. It only shows what their binaries declare
# about themselves: the static oled binary carries an ELF package note for the
# Ubuntu C runtime it was linked with. Go binaries such as Docker's are
# catalogued from the build information embedded in them.

set -euo pipefail

SYFT_VERSION=1.57.1
CYCLONEDX_VERSION=0.33.1

# SHA-256 of each release asset, as GitHub reports it for the release. Pinned
# so the SBOM is always made and checked by exactly these binaries: if an asset
# ever changes, the download fails instead of producing a different SBOM.
# cyclonedx-cli publishes no checksums file of its own.
declare -A SYFT_SHA256=(
    [amd64]=bf52519eb57f675d47c07d43213cb6dff6449f3d6d1147ff6701ed91f44eef0c
    [arm64]=aa3d3e07344f590bcce8d31043b752daa76c8a56c2aa34ceeee63c6168152582
)
declare -A CYCLONEDX_SHA256=(
    [x64]=bfc8b2538da86fe239bc53658bbb63c1c8c510a293c1e6891aa5bea5d3c58746
    [arm64]=b2e9fdf9665ef49868a2ec012171c6e785dcd69745bc5869e53e4f4bfb096a5f
)

CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/rakpios-sbom"

die() {
    echo "sbom: $*" >&2
    exit 1
}

usage() {
    echo "usage: tools/sbom.sh <image.img.xz>" >&2
    exit 2
}

[ "$#" -eq 1 ] || usage
IMAGE="$1"
[ -f "${IMAGE}" ] || die "${IMAGE}: no such file"
case "${IMAGE}" in
    *.img.xz) ;;
    *) die "${IMAGE}: expected a .img.xz image" ;;
esac

for cmd in curl xz sfdisk dd debugfs jq sha256sum tar; do
    command -v "${cmd}" > /dev/null || die "${cmd} is needed but not installed"
done

case "$(uname -m)" in
    x86_64)  syft_arch=amd64; cyclonedx_arch=x64 ;;
    aarch64) syft_arch=arm64; cyclonedx_arch=arm64 ;;
    *) die "no pinned Syft and cyclonedx-cli binaries for $(uname -m)" ;;
esac

# Download a release asset into the cache unless a copy with the pinned hash
# is already there.
fetch() {
    local url="$1" sha256="$2" dest="$3"
    if [ -f "${dest}" ] && echo "${sha256}  ${dest}" | sha256sum -c --status; then
        return
    fi
    mkdir -p "$(dirname "${dest}")"
    curl -fsSL -o "${dest}.part" "${url}" || die "download failed: ${url}"
    if ! echo "${sha256}  ${dest}.part" | sha256sum -c --status; then
        rm -f "${dest}.part"
        die "checksum mismatch for ${url}: the release asset is not the pinned one"
    fi
    mv "${dest}.part" "${dest}"
}

syft_tarball="${CACHE_DIR}/syft_${SYFT_VERSION}_linux_${syft_arch}.tar.gz"
fetch "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${syft_arch}.tar.gz" \
    "${SYFT_SHA256[${syft_arch}]}" "${syft_tarball}"

CYCLONEDX="${CACHE_DIR}/cyclonedx-${CYCLONEDX_VERSION}-linux-${cyclonedx_arch}"
fetch "https://github.com/CycloneDX/cyclonedx-cli/releases/download/v${CYCLONEDX_VERSION}/cyclonedx-linux-${cyclonedx_arch}" \
    "${CYCLONEDX_SHA256[${cyclonedx_arch}]}" "${CYCLONEDX}"
chmod 755 "${CYCLONEDX}"

export SYFT_CHECK_FOR_APP_UPDATE=false
# cyclonedx-cli is a .NET program; without this it needs the ICU libraries on
# the host, and validating a schema doesn't need locale data
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

image_dir=$(cd "$(dirname "${IMAGE}")" && pwd)
name=$(basename "${IMAGE}" .img.xz)
OUT="${image_dir}/${name}.cdx.json"

WORK=$(mktemp -d "${SBOM_WORKDIR:-${image_dir}}/.sbom-${name}.XXXXXX")
trap 'rm -rf "${WORK}"' EXIT

# Unpack Syft from the tarball whose hash was just checked, every run: a binary
# left in the cache could have come from anywhere.
tar -xzf "${syft_tarball}" -C "${WORK}" syft
SYFT="${WORK}/syft"

# --- Extract the root filesystem ------------------------------------------------
#
# The partition table is in the first MiB, so read that, then stream only the
# root partition (the second one) out of the archive. The whole image is never
# written to disk.
echo "sbom: reading ${IMAGE}"
xz -dc "${IMAGE}" | head -c 1048576 > "${WORK}/head.img" || true
read -r start size < <(sfdisk -J "${WORK}/head.img" | jq -r '.partitiontable.partitions[1] | "\(.start) \(.size)"')
[[ "${start}" =~ ^[0-9]+$ ]] && [[ "${size}" =~ ^[0-9]+$ ]] || die "can't find the root partition in ${IMAGE}"
xz -dc "${IMAGE}" | dd of="${WORK}/root.ext4" bs=4M status=none iflag=skip_bytes,count_bytes,fullblock \
    skip=$((start * 512)) count=$((size * 512)) || true
[ "$(stat -c %s "${WORK}/root.ext4")" -eq $((size * 512)) ] || die "the root partition came out truncated"
rm -f "${WORK}/head.img"

# debugfs reports every chown it can't do without root; ownership doesn't
# matter for cataloguing, and the dpkg database check below catches a failed dump
mkdir "${WORK}/rootfs"
debugfs -R "rdump / ${WORK}/rootfs" "${WORK}/root.ext4" > /dev/null 2>&1 || true
rm -f "${WORK}/root.ext4"
STATUS="${WORK}/rootfs/var/lib/dpkg/status"
[ -s "${STATUS}" ] || die "no dpkg database in the extracted root filesystem"

# The version on the release is the image's own, IMAGE_VERSION (RAKPiOS 1.1.0
# and later); VERSION_ID is Debian's major
read -r image_version debian_major < <(
    # shellcheck source=/dev/null
    . "${WORK}/rootfs/usr/lib/os-release"
    echo "${IMAGE_VERSION:--} ${VERSION_ID:--}"
)
[ "${image_version}" != "-" ] || die "the image's os-release has no IMAGE_VERSION: not a RAKPiOS 1.1.0 or later image"

# --- Catalogue and validate -----------------------------------------------------
#
# The 'image' catalogers read the directory as an installed system (dpkg
# database, embedded Go build info), not as a source tree.
echo "sbom: cataloguing with Syft ${SYFT_VERSION}"
"${SYFT}" scan "dir:${WORK}/rootfs" -q --override-default-catalogers image \
    --source-name "${name}" --source-version "${image_version}" \
    -o "cyclonedx-json@1.6=${WORK}/sbom.cdx.json"

validate() {
    "${CYCLONEDX}" validate --input-file "${WORK}/sbom.cdx.json" --input-format json \
        --input-version v1_6 --fail-on-errors > "${WORK}/validate.log" 2>&1
}

# On failure the validator prints the whole SBOM along with the errors, so show
# only the short lines
validation_errors() {
    awk 'length($0) < 300' "${WORK}/validate.log" | grep -v '^$' | head -40 >&2
}

echo "sbom: validating against the CycloneDX 1.6 schema with cyclonedx-cli ${CYCLONEDX_VERSION}"
fixed_licenses=""
if ! validate; then
    # CycloneDX 1.6 accepts only the SPDX licence ids in its own copy of the
    # SPDX list, and that copy is older than Syft's. Syft writes ids SPDX has
    # added since, such as OSSP (Debian's ossp-uuid packages), and the SBOM
    # then fails validation, which consumers that check the schema reject.
    # For each id the validator refuses, write the same text as a licence
    # name instead, which 1.6 allows for any licence, and validate again. Any
    # other error still fails.
    fixes=$(sed -n 's|^On instance: /components/\([0-9]*\)/licenses/\([0-9]*\)/license/id:$|[\1,\2]|p' "${WORK}/validate.log" | sort -u | paste -sd, -)
    if [ -z "${fixes}" ]; then
        validation_errors
        die "the SBOM is not valid CycloneDX 1.6"
    fi
    fixed_licenses=$(jq -r --argjson fix "[${fixes}]" '[$fix[] as [$c, $l] | "\(.components[$c].licenses[$l].license.id) (\(.components[$c].name))"] | unique | join(", ")' "${WORK}/sbom.cdx.json")
    jq --argjson fix "[${fixes}]" 'reduce $fix[] as [$c, $l] (.; .components[$c].licenses[$l].license |= ({name: .id} + del(.id)))' \
        "${WORK}/sbom.cdx.json" > "${WORK}/sbom.fixed.json"
    mv "${WORK}/sbom.fixed.json" "${WORK}/sbom.cdx.json"
    echo "sbom: licence ids not in CycloneDX 1.6's SPDX list, written as names: ${fixed_licenses}"
    if ! validate; then
        validation_errors
        die "the SBOM is not valid CycloneDX 1.6 even with those licences written as names"
    fi
fi
echo "sbom: valid CycloneDX 1.6"

# --- Check that the SBOM is usable ------------------------------------------------
#
# The point of the SBOM is that vulnerability tools can match it: the distro
# must read as Debian 13 and the package URLs must be Debian's. 1.0.0's said
# "rakpios" and matched nothing.
failures=0
fail() { echo "sbom: $*" >&2; failures=$((failures + 1)); }

# Syft refines VERSION_ID with the point release from /etc/debian_version
# ("13.8"); scanners match Debian on the major
os=$(jq -r '[.components[] | select(.type == "operating-system") | "\(.name) \(.version)"] | join(", ")' "${WORK}/sbom.cdx.json")
[[ "${os}" =~ ^debian\ ${debian_major}(\.[0-9]+)?$ ]] || fail "operating system is '${os}', not 'debian ${debian_major}'"

syft_used=$(jq -r '[.metadata.tools.components[]? | select(.name == "syft") | .version] | join(", ")' "${WORK}/sbom.cdx.json")
[ "${syft_used}" = "${SYFT_VERSION}" ] || fail "made by Syft '${syft_used}', not ${SYFT_VERSION}"

# Every package in the dpkg database must be there, under Debian's namespace.
# Other deb package URLs can appear legitimately, from ELF package notes in
# binaries installed outside apt; they're reported, not failed.
dpkg_query='[.components[] | select(any(.properties[]?; .name == "syft:package:foundBy" and .value == "dpkg-db-cataloger"))]'
dpkg_components=$(jq "${dpkg_query} | length" "${WORK}/sbom.cdx.json")
dpkg_not_debian=$(jq -r "${dpkg_query} | map(select(.purl // \"\" | startswith(\"pkg:deb/debian/\") | not) | .purl // .name) | join(\", \")" "${WORK}/sbom.cdx.json")
installed=$(grep -c '^Status: install ok installed$' "${STATUS}")
[ -z "${dpkg_not_debian}" ] || fail "dpkg packages without a pkg:deb/debian/ package URL: ${dpkg_not_debian}"
[ "${dpkg_components}" -eq "${installed}" ] || fail "${dpkg_components} components from the dpkg database, but ${installed} packages installed in the image"

if [ "${failures}" -ne 0 ]; then
    mv "${WORK}/sbom.cdx.json" "${OUT}.rejected"
    die "${failures} check(s) failed; no SBOM written (the rejected one is ${OUT}.rejected, for inspection)"
fi

count() { jq "[.components[] | select($1)] | length" "${WORK}/sbom.cdx.json"; }
go_components=$(count '.purl // "" | startswith("pkg:golang/")')
kernel_modules=$(count 'any(.properties[]?; .name == "syft:package:foundBy" and .value == "linux-kernel-cataloger")')
files=$(count '.type == "file"')
other_deb=$(jq -r '[.components[] | select((.purl // "" | startswith("pkg:deb/")) and (any(.properties[]?; .name == "syft:package:foundBy" and .value == "dpkg-db-cataloger") | not)) | "\(.purl) in \([.properties[]? | select(.name == "syft:location:0:path") | .value] | first)"] | join(", ")' "${WORK}/sbom.cdx.json")
total=$(jq '.components | length' "${WORK}/sbom.cdx.json")

mv "${WORK}/sbom.cdx.json" "${OUT}"
(cd "${image_dir}" && sha256sum "${name}.cdx.json" > "${name}.cdx.json.sha256")

echo "sbom: ${OUT}"
echo "sbom:   ${os}, RAKPiOS ${image_version}, Syft ${SYFT_VERSION}"
echo "sbom:   ${total} components: ${dpkg_components} Debian packages (= installed), ${go_components} Go modules, ${kernel_modules} kernel modules and kernels, ${files} package files"
[ -z "${other_deb}" ] || echo "sbom:   declared by binaries outside apt: ${other_deb}"
[ -z "${fixed_licenses}" ] || echo "sbom:   licences written as names for CycloneDX 1.6: ${fixed_licenses}"
echo "sbom:   sha256 $(cut -d' ' -f1 "${OUT}.sha256")"
