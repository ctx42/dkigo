#!/usr/bin/env bash
#
# Build the dkigo images straight from configs/project.conf - no extra tooling
# required. Every build argument (versions, paths, registry) comes from that
# file; the OCI label metadata is derived from git.
#
# Runs from any working directory — paths resolve relative to this script.
#
# Usage:
#   ./bin/build.sh          # build all targets in C42_BLD_TARGETS
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

# Targets: command-line arguments override C42_BLD_TARGETS.
if [ "$#" -gt 0 ]; then
	targets=("$@")
else
	targets=(${C42_BLD_TARGETS//,/ })
fi

rev="$(git -C "$ROOT" describe --tags --always)"

for target in "${targets[@]}"; do
	image="$C42_REG_REPO/dkigo-$target:$rev"
	echo "[dkigo] building $image"

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
		--build-arg C42_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--build-arg C42_CCID="$rev" \
		--build-arg C42_SCM_HASH="$(git -C "$ROOT" rev-parse --short HEAD)" \
		--build-arg C42_SCM_REV="$rev" \
		--build-arg C42_SCM_REPO="https://github.com/ctx42/dkigo" \
		--ssh default \
		--target "$target" \
		"${cache[@]}" \
		"${output[@]}" \
		-t "$image" \
		"$ROOT"
done
