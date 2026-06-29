#!/usr/bin/env bash
set -eu

DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

export USE_EXISTING_PIGEN_IMAGE=1
export PIGEN_IMAGE="${PIGEN_IMAGE:-pi-gen:latest}"

exec "${DIR}/build-docker.sh" "$@"
