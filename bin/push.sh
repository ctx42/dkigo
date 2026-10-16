#!/usr/bin/env bash
#
# Push the dkigo images built by build.sh to the registry. The image tags come
# from the same configs/project.conf, the same environment overrides resolved
# by cmd/cfgenv, and the same cmd/scmver derivation build.sh uses, so a plain
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

# Load the build configuration with cmd/cfgenv, which resolves it the way
# gomake does: an environment variable named like a key in the file overrides
# that key's value, an empty value included, before $VAR expansion, so values
# derived from it follow; the file itself is the list of keys that may be
# overridden. It prints one "[dkigo] override KEY=value" line per overridden
# key to standard error. The output is captured before it is evaluated so a
# failing cfgenv stops the script under `set -e`.
mkdir -p "$ROOT/tmp"
cfgenv="$ROOT/tmp/cfgenv"
go -C "$ROOT" build -o "$cfgenv" ./cmd/cfgenv
cfg_env="$("$cfgenv" "$ROOT")"
set -a
eval "$cfg_env"
set +a

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
