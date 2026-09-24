#!/usr/bin/env bash
#
# Build the dkigo images straight from configs/project.conf - no tooling beyond
# Go and Docker required. Every build argument (versions, paths, registry)
# comes from that file; the version and OCI label metadata come from
# cmd/scmver.
#
# Runs from any working directory — paths resolve relative to this script.
#
# Usage:
#   ./bin/build.sh          # build all targets in C42_BLD_IMG_TARGETS
#   ./bin/build.sh base     # build only the given target(s)
#
# Optional environment variables (unset = plain local build into the daemon):
#   C42_BLD_CACHE=gha       # read/write a GitHub Actions layer cache (mode=max)
#   C42_BLD_PUSH=1          # push straight to the registry instead of loading
#                           # the image into the local daemon
#
# C42_BLD_CACHE=gha needs a docker-container buildx builder (as created by
# docker/setup-buildx-action in CI); the default "docker" driver cannot export
# a mode=max cache.
#
# --ssh default is required only by the ssh-keyscan step that seeds
# known_hosts; it does not need a loaded key, since all fetches are public.

set -euo pipefail

# Resolve the repository root (this script lives in ./bin) so it works from
# any directory.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/configs/project.conf"

# Load the build configuration.
set -a
# shellcheck disable=SC1090
. "$CONF"
set +a

# Targets: command-line arguments override C42_BLD_IMG_TARGETS.
if [ "$#" -gt 0 ]; then
	targets=("$@")
else
	targets=(${C42_BLD_IMG_TARGETS//,/ })
fi

# Compile cmd/scmver and run it for C42_SCM_REV, C42_SCM_HASH, img_tag and
# is_release. It derives the version with the gmtask pinned in go.mod - the
# same code gomake stamps binaries with. The output is captured before it is
# evaluated so a failing scmver stops the script under `set -e`.
scmver="$ROOT/tmp/scmver"
mkdir -p "$ROOT/tmp"
go -C "$ROOT" build -o "$scmver" ./cmd/scmver
scm_env="$("$scmver" "$ROOT")"
eval "$scm_env"

# Build date as RFC3339 with a three-digit fraction - the layout xdef renders
# (xdef.BldDateStr), which keeps every date the same width. %N is nanoseconds;
# not every date implementation honours the %3N width flag, so truncate here
# and fall back to a zero fraction when %N produced nothing usable.
bld_date="$(date -u +%Y-%m-%dT%H:%M:%S.%N)"
if [ "${#bld_date}" -eq 29 ]; then
	bld_date="${bld_date:0:23}Z"
else
	bld_date="$(date -u +%Y-%m-%dT%H:%M:%S).000Z"
fi

for target in "${targets[@]}"; do
	image="$C42_REG_REPO/dkigo-$target:$img_tag"
	echo "[dkigo] building $image"

	# Only a release - a clean tree on a semver tag that is not a pre-release -
	# moves `latest`.
	tags=(-t "$image")
	if [ "$is_release" = "1" ]; then
		latest="$C42_REG_REPO/dkigo-$target:latest"
		echo "[dkigo] tagging $latest"
		tags+=(-t "$latest")
	fi

	# Per-target GitHub Actions cache (mode=max caches the intermediate builder
	# stages too, where the expensive tool installs live). Off unless requested.
	cache=()
	if [ "${C42_BLD_CACHE:-}" = "gha" ]; then
		cache+=(--cache-from "type=gha,scope=$target")
		cache+=(--cache-to "type=gha,mode=max,scope=$target")
	fi

	# Push straight to the registry, or leave the image in the local daemon.
	output=()
	if [ "${C42_BLD_PUSH:-}" = "1" ]; then
		output+=(--push)
	fi

	docker buildx build \
		$(sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/--build-arg \1/p' "$CONF") \
		--build-arg C42_BLD_DATE="$bld_date" \
		--build-arg C42_SCM_HASH="$C42_SCM_HASH" \
		--build-arg C42_SCM_REV="$C42_SCM_REV" \
		--build-arg C42_SCM_REPO="https://github.com/ctx42/dkigo" \
		--ssh default \
		--target "$target" \
		"${cache[@]}" \
		"${output[@]}" \
		"${tags[@]}" \
		"$ROOT"
done
