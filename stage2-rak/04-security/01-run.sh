#!/bin/bash -e

# Security settings that have to see the final package set, so this substage
# runs last. It removes packages a gateway doesn't need, turns on automatic
# updates, keeps Docker upgrades from stopping containers, and then checks all
# of it: each of these could otherwise do nothing without anyone noticing.

ADMINDIR="${ROOTFS_DIR}/var/lib/dpkg"

installed_packages() {
    # shellcheck disable=SC2016 # the ${...} are dpkg-query fields, not shell
    dpkg-query --admindir="${ADMINDIR}" -W -f='${db:Status-Abbrev} ${Package}\n' | awk '$1 == "ii" { print $2 }' | sort
}

# --- Remove packages a gateway doesn't need ------------------------------------
#
# - rpicam-apps-lite and mkvtoolnix: the camera stack, which pulls in Qt6 core
#   and libtiff.
# - docker-model-plugin: installed by get.docker.com. It carries most of the Go
#   CVEs left after a rebuild, and nothing in RAKPiOS uses it.
# - rpi-connect-lite: Raspberry Pi's remote access service, a second way in
#   next to SSH. Its units are user units that nothing enables, so removing the
#   package leaves nothing behind.
#
# autoremove then takes their dependencies, which hold most of the CVEs. It can
# also take any other automatically installed package that nothing needs any
# more, so the build log lists everything that left. Nothing installed depends
# on or recommends the four, so upgrades don't bring them back without a pin,
# and `sudo apt install <name>` still can.
REMOVED_PACKAGES="rpicam-apps-lite mkvtoolnix rpi-connect-lite docker-model-plugin"
before=$(installed_packages)
on_chroot << EOF
apt-get purge -y ${REMOVED_PACKAGES}
apt-get autoremove --purge -y
EOF
after=$(installed_packages)
echo "Packages removed ($(comm -23 <(echo "${before}") <(echo "${after}") | wc -l)):"
comm -23 <(echo "${before}") <(echo "${after}") | sed 's/^/    /'

# --- Automatic updates -----------------------------------------------------------
#
# unattended-upgrades itself is installed by 00-packages-nr, switched on by
# 00-debconf. This adds RAKPiOS's list of allowed origins and the no-reboot
# rule, and the command that turns the updates on and off.
install -m 644 files/52rakpios-unattended-upgrades "${ROOTFS_DIR}/etc/apt/apt.conf.d/"
install -m 755 files/rakpios-auto-updates "${ROOTFS_DIR}/usr/local/bin/"

# --- Docker ------------------------------------------------------------------------
#
# Every docker-ce upgrade restarts dockerd (prerm stops it, postinst starts it),
# and without live-restore that stops every container. The ones without a
# restart policy then stay down, among them rakpios-cli services that don't
# set one. With live-restore, containers keep running while dockerd restarts.
# Side effect: `systemctl stop docker` no longer stops containers either.
#
# Nothing else in the build writes daemon.json today. If something ever does,
# refuse to overwrite it, so its settings aren't lost without anyone noticing.
if [ -e "${ROOTFS_DIR}/etc/docker/daemon.json" ]; then
    echo "04-security: ${ROOTFS_DIR}/etc/docker/daemon.json already exists; merge live-restore into it instead of overwriting" >&2
    exit 1
fi
install -d -m 755 "${ROOTFS_DIR}/etc/docker"
install -m 644 files/daemon.json "${ROOTFS_DIR}/etc/docker/"

# Live restore is only reliable between consecutive Docker releases, so a new
# major version is a deliberate step, not an automatic one: docker-ce and its
# CLI are pinned to the major installed now. containerd versions on its own,
# and its upgrade restarts containerd under the running containers, so it is
# held to its own major. A priority above the default 500 makes the held major
# win over a newer one; staying below 1000 means apt never downgrades. The CLI
# plugins aren't held: they run no daemon.
docker_version=$(dpkg-query --admindir="${ADMINDIR}" -W -f='${Version}' docker-ce)
containerd_version=$(dpkg-query --admindir="${ADMINDIR}" -W -f='${Version}' containerd.io)
docker_major="${docker_version%%.*}"           # 5:29.10.0-1~debian.13~trixie -> 5:29
containerd_major="${containerd_version%%.*}"   # 2.4.2-4~debian.13~trixie -> 2
if ! [[ "${docker_major}" =~ ^[0-9]+:[0-9]+$ ]] || ! [[ "${containerd_major}" =~ ^[0-9]+$ ]]; then
    echo "04-security: can't read the Docker majors from docker-ce '${docker_version}' and containerd.io '${containerd_version}'" >&2
    exit 1
fi
cat > "${ROOTFS_DIR}/etc/apt/preferences.d/docker-major-hold" << EOF
Explanation: RAKPiOS keeps Docker on the major version this image shipped with.
Explanation: Live restore keeps containers running through a Docker upgrade only
Explanation: between consecutive releases, so moving to a new major is a deliberate
Explanation: step: change the version below (or delete this file), then run
Explanation: sudo apt update && sudo apt full-upgrade.
Explanation: Patch and minor releases within the major still install automatically.
Package: docker-ce docker-ce-cli docker-ce-rootless-extras
Pin: version ${docker_major}.*
Pin-Priority: 990

Explanation: containerd versions on its own, and its upgrade restarts containerd
Explanation: under the running containers, so it is held to its own major too.
Package: containerd.io
Pin: version ${containerd_major}.*
Pin-Priority: 990
EOF
chmod 644 "${ROOTFS_DIR}/etc/apt/preferences.d/docker-major-hold"

# --- Check the result ------------------------------------------------------------
#
# Everything above can silently do nothing (a purge that misses, a config file
# another one overrides, a pin that doesn't match), so check the final state as
# the running system will see it.
checks=$(on_chroot << 'EOF'
echo "periodic-lists=$(apt-config dump APT::Periodic::Update-Package-Lists)"
echo "periodic-upgrade=$(apt-config dump APT::Periodic::Unattended-Upgrade)"
echo "reboot=$(apt-config dump Unattended-Upgrade::Automatic-Reboot)"
apt-config dump Unattended-Upgrade::Origins-Pattern | sed -n 's/^Unattended-Upgrade::Origins-Pattern:: "\(.*\)";$/pattern=\1/p'
echo "status=$(rakpios-auto-updates status)"
echo "timers=$(systemctl is-enabled apt-daily.timer apt-daily-upgrade.timer 2>/dev/null | tr '\n' ' ')"
echo "live-restore=$(jq -r '."live-restore"' /etc/docker/daemon.json 2>&1)"
for p in docker-ce containerd.io; do
    echo "pin-${p}=$(apt-cache policy "${p}" | awk '$1 == "***" { print $3 }')"
done
EOF
)
echo "04-security: state as the system sees it:"
echo "    ${checks//$'\n'/$'\n'    }"

failures=0
fail() { echo "04-security: $*" >&2; failures=$((failures + 1)); }
value() { echo "${checks}" | sed -n "s/^$1=//p"; }

for p in ${REMOVED_PACKAGES}; do
    # shellcheck disable=SC2016 # dpkg-query field, not shell
    status=$(dpkg-query --admindir="${ADMINDIR}" -W -f='${db:Status-Abbrev}' "${p}" 2>/dev/null || true)
    case "${status:0:2}" in
        ""|un|pn) ;;
        *) fail "${p} is still on the image (dpkg status '${status}')" ;;
    esac
done

[ "$(value periodic-lists)" = 'APT::Periodic::Update-Package-Lists "1";' ] || fail "daily package list update is not on: $(value periodic-lists)"
[ "$(value periodic-upgrade)" = 'APT::Periodic::Unattended-Upgrade "1";' ] || fail "daily unattended upgrade is not on: $(value periodic-upgrade)"
[ "$(value reboot)" = 'Unattended-Upgrade::Automatic-Reboot "false";' ] || fail "automatic reboot is not off: $(value reboot)"
# shellcheck disable=SC2016 # ${distro_codename} is expanded by unattended-upgrades
expected_patterns='origin=Debian,codename=${distro_codename},label=Debian
origin=Debian,codename=${distro_codename}-security,label=Debian-Security
origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation
origin=Docker,label=Docker CE'
[ "$(value pattern)" = "${expected_patterns}" ] || fail "allowed origins are not exactly RAKPiOS's four: $(value pattern | tr '\n' ';')"
[ "$(value status)" = "on" ] || fail "rakpios-auto-updates status says '$(value status)', not 'on'"
[ "$(value timers)" = "enabled enabled " ] || fail "apt-daily and apt-daily-upgrade timers are not both enabled: $(value timers)"
[ "$(value live-restore)" = "true" ] || fail "live-restore is not on in /etc/docker/daemon.json: $(value live-restore)"
[ "$(value pin-docker-ce)" = "990" ] || fail "the installed docker-ce isn't held by the major pin (priority '$(value pin-docker-ce)', want 990)"
[ "$(value pin-containerd.io)" = "990" ] || fail "the installed containerd.io isn't held by the major pin (priority '$(value pin-containerd.io)', want 990)"

if [ "${failures}" -ne 0 ]; then
    echo "04-security: ${failures} check(s) failed, stopping the build" >&2
    exit 1
fi
echo "04-security: all checks passed (Docker held at ${docker_major}.*, containerd at ${containerd_major}.*)"
