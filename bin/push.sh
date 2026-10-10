#!/usr/bin/env bash
#
# Push the dkigo images built by build.sh to the registry. The image tags come
# from the same configs/project.conf, the same environment overrides, and the
# same cmd/scmver derivation build.sh uses, so a plain
# `./build.sh && ./push.sh` run with the same environment publishes what was
# just built.
#
# Runs from any working directory — paths resolve relative to this script.
#
# Usage:
#   ./bin/push.sh           # push all targets in C42_BLD_IMG_TARGETS
#   ./bin/push.sh base      # push only the given target(s)
#
# CI builds with C42_BLD_PUSH=1 and does not need this script; use it for the
# local "build locally, then push" flow (see build.sh).

set -euo pipefail

# Resolve the repository root (this script lives in ./bin) so it works from
# any directory.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/configs/project.conf"

# Load the build configuration. An environment variable named like a key in
# the file overrides that key's value, an empty value included; the file
# itself is the list of keys that may be overridden. Save the overriding
# values before sourcing the file and restore them after it.
mapfile -t keys < <(sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1/p' "$CONF")
declare -A overrides=()
for key in "${keys[@]}"; do
	if [ -n "${!key+set}" ]; then
		overrides[$key]="${!key}"
	fi
done
set -a
# shellcheck disable=SC1090
. "$CONF"
set +a
for key in "${keys[@]}"; do
	if [ -n "${overrides[$key]+set}" ]; then
		printf -v "$key" '%s' "${overrides[$key]}"
		echo "[dkigo] override $key=${overrides[$key]}"
	fi
done

# Targets: command-line arguments override C42_BLD_IMG_TARGETS.
if [ "$#" -gt 0 ]; then
	targets=("$@")
else
	targets=(${C42_BLD_IMG_TARGETS//,/ })
fi

# Compile cmd/scmver and run it, exactly as build.sh does, for C42_SCM_REV,
# C42_SCM_HASH, img_tag and is_release. It derives the version with the gmtask
# pinned in go.mod - the same code gomake stamps binaries with. The output is
# captured before it is evaluated so a failing scmver stops the script under
# `set -e`.
scmver="$ROOT/tmp/scmver"
mkdir -p "$ROOT/tmp"
go -C "$ROOT" build -o "$scmver" ./cmd/scmver
scm_env="$("$scmver" "$ROOT")"
eval "$scm_env"

for target in "${targets[@]}"; do
	image="$C42_REG_REPO/dkigo-$target:$img_tag"
	echo "[dkigo] pushing $image"
	docker push "$image"

	# Only a release - a clean tree on a semver tag that is not a pre-release -
	# pushes `latest`, which build.sh tagged under the same rule.
	if [ "$is_release" = "1" ]; then
		latest="$C42_REG_REPO/dkigo-$target:latest"
		echo "[dkigo] pushing $latest"
		docker push "$latest"
	fi
done
