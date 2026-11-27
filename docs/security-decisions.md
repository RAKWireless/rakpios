# RAKPiOS security decisions

This document records the security decisions behind RAKPiOS, starting with release 1.1.0 (November 2026). Each entry says what was decided, which alternatives were considered, why this one was chosen, and what it costs. An entry is updated when its decision changes, and the change is dated.

It is part of RAK's technical documentation for the EU Cyber Resilience Act (CRA), which has to be kept for ten years. It lives in this repository so that it is versioned with the code that implements it. RAKPiOS's risk assessment is a separate RAK document; the decisions and numbers here are input to it.

The vulnerability counts come from scanning the release images with Syft and Grype, against the Grype vulnerability database of the day.

## Release scope

### One release for all the changes

RAKPiOS 1.1.0 brings together a fresh build against current archives, the `os-release` change, automatic updates and the package removal. An earlier proposal split them: a 1.0.1 with the rebuild and `os-release` first, then 1.1.0.

- **Why:** less release overhead. Automatic updates and the removals change behaviour, so semantic versioning needs a minor version anyway.
- **Cost:** the image fix for the known-exploited brotli vulnerability (CVE-2026-111497) waited for the slower work. Devices already in the field could get it earlier with `sudo apt update && sudo apt full-upgrade`.

### Based on upstream pi-gen 2026-10-06

1.1.0 merges the latest upstream Raspberry Pi OS trixie tag, `2026-10-06-raspios-trixie-arm64`, before any RAKPiOS change.

- **Why:** the image is rebuilt anyway, and the tag brings upstream's build fixes.
- **What it doesn't do:** fix vulnerabilities by itself. Package and kernel versions come from the archives on the day the image is built, whatever the tag.
- **Cost:** the same three merge conflicts as the previous upstream merge (`Dockerfile`, `README.md`, `build-docker.sh`). RAKPiOS's fix for building on a host with no loop devices yet has to survive each one.

## Image identity

### Debian identity in `os-release`, RAKPiOS in the image fields

`/etc/os-release` says `ID=debian`, `VERSION_ID=13` and `VERSION="13 (trixie)"`. RAKPiOS goes in `NAME`, `PRETTY_NAME`, `IMAGE_ID=rakpios` and `IMAGE_VERSION`. `ID_LIKE` is no longer set.

- **Why:** 1.0.0 said `ID=rakpios` and `VERSION_ID=rakpios-1.0.0-arm64`. With that, Grype matched 0 of the image's packages (5,328 matches with `VERSION_ID=13`), and SBOM package URLs (`pkg:deb/rakpios/…`) matched nothing in OSV or Dependency-Track. Every vulnerability report about 1.0.0 was silently empty. `IMAGE_ID` and `IMAGE_VERSION` are the standard freedesktop.org fields for a derived image. `ID_LIKE=debian` is redundant once `ID=debian`, and Debian's own file doesn't set it.
- **Cost:** anything that read the RAKPiOS version from `VERSION_ID` breaks. The OLED panel was fixed (next entry). The hardware test suite's system report now prints `OS: 13`; that is cosmetic and left as it is. `rakpios-cli` and `mioty-cli` don't read `os-release`, and the MOTD reads `PRETTY_NAME`.

### The OLED panel reads `IMAGE_VERSION`

The OLED status panel 3.1.0 shows `IMAGE_VERSION`, and falls back to `VERSION_ID` with `rakpios-` stripped, so the same binary is right on 1.0.0. The alternative was to accept the panel showing `13` until a later release.

- **Why:** an earlier assessment said nothing else read `os-release`. That was wrong: the panel's intro page showed `VERSION_ID`.
- **Cost:** a release of the panel had to come out before the image could be built.

### `os-release` is kept across `base-files` upgrades

The image diverts `/usr/lib/os-release` to `/usr/lib/os-release.debian` with a local `dpkg-divert` before writing RAKPiOS's file, and the build checks that the diversion is in place.

- **Why:** `base-files` owns `/usr/lib/os-release` as a plain file, not a configuration file, so every `base-files` upgrade overwrites it. Debian ships one with each point release, and RAKPiOS installs point releases automatically. Without the diversion, the first one would silently turn the device back into "Debian GNU/Linux": the MOTD would say Debian, the OLED panel would show `13`, and `IMAGE_VERSION`, `COMMIT_SHA` and `COMMIT_DATE` would disappear.
- **Alternatives:** an apt hook that rewrites the file after every dpkg run is more code for the same job; holding `base-files` would block Debian's fixes to it; a RAKPiOS `base-files` package needs an apt repository that doesn't exist yet.
- **Cost:** the RAKPiOS file is frozen at build time. It keeps saying `VERSION_ID=13` through point releases, which is correct because the major version doesn't change. Debian's current copy stays readable at `/usr/lib/os-release.debian`. 1.0.0 has no diversion, so a 1.0.0 device that runs `apt full-upgrade` reports itself as Debian from then on.

## Attack surface

### Removed: the camera stack, `docker-model-plugin` and `rpi-connect-lite`; kept: the developer toolchain

The image removes `rpicam-apps-lite`, `mkvtoolnix`, `docker-model-plugin` and `rpi-connect-lite`. It keeps `build-essential`, `gdb`, `manpages-dev`, `pkg-config`, `python3-pip`, `python3-virtualenv`, `vim` and `git`.

- **Why remove:** the camera stack has no use on a LoRaWAN gateway and pulls in Qt 6 core and libtiff. `docker-model-plugin` carried 18 of the 29 Go-module CVEs left after a plain rebuild, and no RAK service uses it. `rpi-connect-lite` is a second remote-access path next to SSH.
- **Why keep:** the RAK7391 is sold as a developer gateway, and `rakpios-cli` needs `git` to install, update and deploy services.
- **Cost:** in 1.1.0 the toolchain accounts for 47 of the 621 vulnerabilities that remain in its Debian packages (14 High, none Critical), mostly in `python3-virtualenv`, `python3-filelock` and `gdb`. Removing it wouldn't remove the others it touches, because the Python runtime and libraries it shares are needed anyway. RAK's risk assessment carries this number.

### Removal with `purge`, then `autoremove`

The build purges the four packages, runs `apt-get autoremove --purge`, and logs every package that left (42 in 1.1.0: the four and 38 dependencies). The alternative was purging an explicit list of their dependencies.

- **Why:** most of the reduction is in the dependencies, and an explicit list would have to be maintained by hand through every upstream change. The build log records what was removed, and testing on hardware catches breakage.
- **Cost:** `autoremove` also removes any other automatically installed package that nothing needs any more. None was found in 1.1.0, but one can't be ruled out in advance.

## Updates

### Automatic updates from Debian, Debian-Security, the Raspberry Pi archive and Docker

`unattended-upgrades` is on by default and installs updates from Debian-Security (`trixie-security`), Debian point releases (`trixie`), the whole Raspberry Pi archive including kernel and firmware, and Docker CE within its held major version (see below).

- **Alternatives:** Debian-Security only; the Raspberry Pi archive without kernel and firmware; no point releases; Docker updated by hand.
- **Why:** the Raspberry Pi archive has no security-only suite, and it carries Raspberry Pi's rebuilds of Debian libraries, glibc among them, which replace Debian's. Leaving out the kernel would leave kernel vulnerabilities in place until someone upgrades by hand. Point releases carry the fixes that never get a Debian security advisory, and Debian enables them by default. Docker's packages hold most of the vulnerabilities outside Debian.
- **Cost:** non-security updates from Raspberry Pi and Docker also arrive unattended. A new kernel installs silently and takes effect at the next reboot.

### `trixie-updates` is not an automatic-update source

- **Why:** this matches Debian's own default configuration. `trixie-updates` carries urgent non-security fixes between point releases; they still arrive with the next point release. Security fixes come through `trixie-security`.
- **Cost:** an urgent non-security fix, time zone data for example, can arrive a few weeks later than it would otherwise.

### No automatic reboots

`Unattended-Upgrade::Automatic-Reboot` is `false`.

- **Why:** gateways run unattended, and an unplanned reboot drops LoRaWAN traffic.
- **Cost:** long-running processes keep the old versions of updated libraries, and a new kernel stays inactive, until someone reboots. The documentation says so.

### An easy opt-out: `rakpios-auto-updates` and a `rakpios-cli` menu

`sudo rakpios-auto-updates off` turns automatic updates off, and `on` turns them back on. `rakpios-cli` 0.3.0 has the same switch under *Automatic updates*. The alternative was the command first, and the menu in a later release.

- **Why:** the CRA asks for an easy way to opt out of automatic security updates (Annex I, Part I, 2(c)), and for this audience a menu is easier than a command.
- **How:** the command installs `unattended-upgrades`' own enabled or disabled `/etc/apt/apt.conf.d/20auto-upgrades`, then reconfigures the package. Changing only the package's stored answer isn't enough, because the package resets that answer from the file. The choice survives upgrades of the package.
- **Cost:** the release had to wait for a `rakpios-cli` release.

### Docker upgrades keep containers running, and the major version is held

`/etc/docker/daemon.json` sets `"live-restore": true`. `docker-ce`, `docker-ce-cli` and `docker-ce-rootless-extras` are pinned to the Docker major version the image was built with, and `containerd.io` to its own (`/etc/apt/preferences.d/docker-major-hold`). The alternatives were Docker with automatic updates and no other change, live-restore without the pin, or Docker updated by hand.

- **Why:** every `docker-ce` upgrade restarts the Docker daemon. Without live-restore, that stops every container, and services without a restart policy stay down. Live-restore keeps them running through the restart. Docker supports live-restore across patch releases, and warns that larger steps, or skipping releases, can stop the new daemon from reattaching to running containers. The major hold keeps out the largest steps. containerd versions independently, and its upgrade restarts containerd under the running containers, so it is held to its major too.
- **Why not hold the minor version:** Docker 29 had a new minor release about every five weeks, from 29.1 in November 2025 to 29.10 in November 2026, and no minor received a patch after the next one shipped. Holding a minor would stop Docker's security fixes within weeks.
- **Cost:**
  - `systemctl stop docker` no longer stops containers.
  - Automatic updates also install Docker minor releases, and a device that was offline for a while may skip releases. Both are outside what Docker supports for live-restore. If the new daemon can't reattach, the containers keep running but Docker can't manage them; they have to be stopped by hand, or the device rebooted.
  - Live-restore covers standalone containers, not Swarm services.
  - If a later Docker release within the held major needed a newer containerd major, apt would hold Docker back, and Docker fixes would stop until the next image.
  - Once Docker stops patching the held major, Docker fixes come only with a new RAKPiOS image or a manual change of the pin.
  - Docker's Go binaries carry vulnerabilities that are fixed in an upstream Go module before Docker ships a release with the fix: 17 in the Docker binaries of 1.1.0. A rebuild can't remove them. The release advisory lists them, and they arrive unattended with the Docker release that fixes them.

## Release criteria and their exceptions

Each release image is scanned on the day it is built and again on the day it is published, for its packages and, separately, for its kernel version. A release doesn't ship with a vulnerability on CISA's Known Exploited Vulnerabilities (KEV) list, or with a vulnerability in a Debian package for which an archive the image uses offers a fix. Packages that Raspberry Pi rebuilds are also checked against Debian's fixes, because the rebuild's version sorts above Debian's and hides them from scanners. The exceptions are recorded here, each with the conditions it rests on.

Go-module vulnerabilities fixed upstream but not yet in a Docker release are reported, not gated, because no archive the image uses offers the fix.

### Known-exploited vulnerabilities that RAKPiOS is not affected by don't block a release

A KEV-listed vulnerability doesn't block a release if RAK has a written analysis showing RAKPiOS is not affected, and that analysis is checked against the image being released. Each one is listed here and in the release advisory. Any other KEV-listed vulnerability still stops the release. The alternative was an absolute rule, waiting for Debian to ship a fix or change its data.

- **Why:** a KEV entry means "exploited somewhere", not "exploitable here". For the one listed below, Debian has judged it Negligible and has no fix planned, so an absolute rule would hold back the release, and every fix in it, indefinitely, for a flaw the image doesn't have.
- **Cost:** an analysis can be wrong, or stop being true, without scanners saying anything new. Each exception therefore names the conditions it rests on, and they are re-checked on every release image. Customers' scanners keep reporting the vulnerability.
- **CVE-2026-123158 (OpenSSH), KEV-listed 9 Nov 2026.** The flaw needs `sshd` running on musl libc without PAM. In RAKPiOS 1.1.0, `sshd`, `sshd-session` and `sshd-auth` link glibc, the image has no musl, authentication links `libpam.so.0`, and `/etc/ssh/sshd_config` sets `UsePAM yes` with no override. Debian rates it Negligible and has no fixed version, so scanners keep matching `openssh-client`, `openssh-server`, `openssh-sftp-server` and `ssh` 1:10.0p1-7+deb13u4. Checked on the 1.1.0 release image.

### 1.1.0 ships while Raspberry Pi's rebuild of glibc 2.41-12+deb13u5 is pending (25 Nov 2026)

1.1.0 ships with glibc `2.41-12+rpt1+deb13u4`, the newest in the Raspberry Pi archive when it was built. It doesn't have the fixes for 14 CVEs that Debian shipped in `2.41-12+deb13u5` on 10 October 2026: CVE-2026-18374, CVE-2026-19499, CVE-2026-19542, CVE-2026-5435, CVE-2026-6238, CVE-2026-6368, CVE-2026-6791, CVE-2026-77117, CVE-2026-80489, CVE-2026-8674, CVE-2026-86805, CVE-2026-89092, CVE-2026-95818 and CVE-2026-97399. The release advisory lists them as open. The exception covers exactly these 14 on glibc's six binary packages. If Raspberry Pi publishes the rebuild before 1.1.0 is published, 1.1.0 still ships as built, and the advisory says that the first automatic update installs it.

- **Alternatives:** wait for Raspberry Pi's rebuild and build again; replace Raspberry Pi's glibc with Debian's, which would need a pin against Raspberry Pi's higher-sorting versions on the library every program links.
- **Why:**
  - Building again can't fix it. Raspberry Pi's `+rpt1` versions sort above Debian's, so apt keeps Raspberry Pi's glibc until Raspberry Pi publishes a newer one.
  - The Raspberry Pi archive is an automatic-update source, so devices install the rebuild by themselves on the first update run after it is published.
  - 1.0.0 is worse on the same package: its glibc misses these fixes and the previous update's. Waiting would leave 1.0.0 in the field for an unknown time, without the 240 Debian CVE fixes and the known-exploited brotli fix that 1.1.0 brings. Raspberry Pi's glibc rebuilds took between 15 and 72 days in 2026.
  - None of the 14 is on the KEV list, and their EPSS scores are between 0.0010 and 0.0036. Two can't be reached on RAKPiOS: CVE-2026-89092 is in `nscd`, which isn't installed, and CVE-2026-97399 is in code built only for POWER8.
- **Cost:** 1.1.0 ships with twelve reachable glibc vulnerabilities that Debian has fixed, two of them rated High: CVE-2026-19499 in `strfmon` and CVE-2026-5435 in the resolver library's record printer. The judgment that none is known to be exploitable rests on the KEV list, EPSS and Debian's descriptions of the fixes, not on an analysis of every program on the image. Devices with automatic updates off stay exposed until their users upgrade, and every device is exposed from first boot until its first update run after the rebuild is out.

### Fixes for programs the image doesn't install don't block a release (26 November 2026)

A vulnerability in a Debian package that has a fix in the image's archives doesn't block a release when the vulnerable program isn't on the image. Each case is listed here with the condition it rests on, which is checked on the release image. A fix for a program the image does install still means a new release image. The alternative was to rebuild for every such fix.

- **Why:** rebuilding would only update packages that don't contain the vulnerable code, and devices install those updates with their first automatic update anyway. Security updates arrive almost daily, so a rule that rebuilds for each one between build and publication can delay a release indefinitely.
- **Cost:** the analysis holds only while the program stays absent. Installing it later brings Debian's current, fixed version. Scanners report the vulnerability on the related packages until the device's first update.
- **CVE-2026-135901 (shadow, DSA-6661-1).** Debian fixed `newgidmap` in 1:4.17.4-2+deb13u1 after the 1.1.0 image was built. `newgidmap` comes with the `uidmap` package, which RAKPiOS 1.1.0 doesn't install. Scanners match `passwd` and `login.defs` only because they're built from the same source, and automatic updates bring their fixed versions.

## Disclosure

### The advisory goes in the GitHub release notes and a GitHub Security Advisory

Each release's security advisory is published on `RAKWireless/rakpios`, in the release notes and as a repository security advisory. The alternatives were the release notes alone, or a page on RAK's website.

- **Why:** it sits next to the image download, and the repository advisory gives it a stable address. This covers the CRA's requirements to disclose fixed vulnerabilities and to publish security updates with advisory information (Annex I, Part II, 4 and 8).
- **How:** GitHub's advisory form is built for software packages. It accepts the "other" ecosystem, so the advisory names the product `rakpios`, affected versions below the release, and lists the CVEs in its text, with no CVE of its own.
- **Cost:** GitHub's Advisory Database and Dependabot don't track the "other" ecosystem, so dependency scanners don't pick the advisory up.

### A CycloneDX SBOM with every release

Each release publishes `<image>.cdx.json` (CycloneDX 1.6), made from the released image file by `tools/sbom.sh` with a pinned Syft and validated against the CycloneDX schema. It is attached to the GitHub release and archived with the image. The alternatives were to archive it and hand it out on request, or to wait for more complete SBOM tooling.

- **Why:** the CRA requires drawing one up and keeping it (Annex I, Part II, 1), not publishing it. But the image is public, so anyone can extract the same package list, and publishing costs nothing. It also gives customers a correct SBOM: 1.0.0's package URLs said `pkg:deb/rakpios/…` and matched nothing.
- **Cost:** it is Syft's standard output, not yet complete to BSI TR-03183-2. RAK's own tools installed outside apt (the OLED panel, `rakpios-cli`, `mioty-cli`, the hardware test suite) aren't in it until they are packaged.

### No VEX in 1.1.0; when it comes, it covers what RAK adds

1.1.0 publishes the advisory, not a VEX document. VEX will start when RAK has a process to triage and record each vulnerability. It will then cover only what RAK adds to Raspberry Pi OS and Debian: components from outside the Debian and Raspberry Pi archives (Docker CE, the OLED panel, `rakpios-cli`, `mioty-cli`, the hardware test suite, wifi-connect, firmware), and RAK's configuration changes that alter whether an upstream package is exploitable (SSH on by default, ModemManager, enabled services). The alternative was a minimal VEX now, with only the OpenSSH not-affected statement.

- **Why:** the CRA asks for disclosure of fixed vulnerabilities, which the advisory provides. A VEX with one statement and hundreds of untriaged vulnerabilities says little. Debian and Raspberry Pi own the assessment of their packages: Debian's tracker statuses `<no-dsa>`, `<postponed>` and `<ignored>` mean "vulnerable, no advisory", not "not affected", so restating them as RAK VEX would be wrong.
- **Cost:** customers who consume VEX get none from RAK yet. The OpenSSH and glibc analyses are in this document and the advisory only.

## How RAKPiOS is built and released

### Where RAK's files live

RAK's image build stages live in `stage2-rak/`, the release scripts in `tools/` (the SBOM script), and the public decision record in `docs/` (this document), together with `config_rak`, `RAKPiOS.md` and `CHANGELOG.md`. The rest of the repository follows upstream pi-gen.

- **Why:** every release needs the SBOM script, and this record has to be kept for ten years. Neither belongs in `stage2-rak/`, which holds only image build stages, or in upstream's `scripts/`.
- **Cost:** two more directories an upstream merge must leave alone. Upstream has neither, so merges don't conflict there.

### Native builds are checked by reading the code only

Each release is built and checked with the Docker build (`build-docker.sh`). The native build (`build.sh`) shares the stages; its own code paths, such as how it records the commit, are checked by reading them.

- **Why:** no build host with root access is set aside for native builds.
- **Cost:** a problem that affects only native builds would go unnoticed until someone builds natively.

### This record lives in the repository

These decisions are kept here, in `docs/security-decisions.md`, and updated on the release branch whenever a decision changes. The alternatives were to keep them in a separate audit repository, or to paste them into RAK's documentation later.

- **Why:** the record is versioned with the code that implements it, and the CRA's technical documentation has to be kept for ten years.
- **Cost:** the repository is public, so the reasoning and the vulnerability counts are public too. That is why this document stands on its own.
