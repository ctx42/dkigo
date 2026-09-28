# Go Docker Images.

Package provides base images for Go projects:

- ghcr.io/ctx42/dkigo-base:vX.Y.Z — tiny runtime base on AlmaLinux micro.
- ghcr.io/ctx42/dkigo-test:vX.Y.Z — full build/test image on AlmaLinux minimal.

## Build Images

The preferred way to build and push the images is
[gomake](https://github.com/ctx42/gomake) with the `:docker:*` targets from
[gmtask](https://github.com/ctx42/gmtask) compiled in — the same tool every
ctx42 project builds its images with. Install the versions `configs/project.conf`
pins:

```shell
mkdir -p /tmp/gomake-install && cd /tmp/gomake-install && go mod init gomake-install
GOFLAGS=-mod=mod go run github.com/ctx42/gomake/cmd/install@v0.27.1 \
    --targets=https://raw.githubusercontent.com/ctx42/gmtask/v0.9.0/targets.yaml
```

Then, from the repository root:

```shell
gomake :docker:image:build -n dkigo -l       # build all targets in C42_BLD_IMG_TARGETS
gomake :docker:image:build -n dkigo -T base  # build only the given target(s)
gomake :docker:image:build -n dkigo -l -d    # print the docker commands, run nothing
```

Always pass `-n dkigo`: gomake prefixes derived image names with `dki-`, which
would publish `dki-dkigo-<target>` instead of `dkigo-<target>`. `-l` also tags
a release `latest` (see [Image Tags](#image-tags)).

### Without gomake

If you'd rather not install gomake, [`bin/build.sh`](bin/build.sh) builds the
same images with nothing but Go and Docker. It sources `configs/project.conf`
for every build argument (versions, paths, registry), compiles and runs
[`cmd/scmver`](cmd/scmver) for the version and OCI label metadata — the same
gmtask code gomake uses, pinned by `go.mod` — and runs `docker buildx build`
once per target. It tags `latest` automatically for a release.

```shell
./bin/build.sh          # build all targets in C42_BLD_IMG_TARGETS
./bin/build.sh base     # build only the given target(s)
```

`C42_BLD_PUSH=1` pushes while building, and `C42_BLD_CACHE=gha` reads and
writes a GitHub Actions layer cache; CI uses both.

## Image Tags

Each image is tagged `$C42_REG_REPO/dkigo-<target>:<version>`, where the
version comes from the git state: a clean checkout of a semver tag builds
`v0.4.0`, anything else builds a pre-release of the next release, such as
`v0.5.0-dev.3.dirty_g7f93fb4`. Which release that is — patch, minor or
major — is read off the Conventional Commits since the tag, and
`C42_BLD_BUMP` overrides it. Untracked files count as changes and make a
build dirty. Only a release is additionally tagged `latest`, and a
pre-release tag such as `v1.0.0-rc.1` is not a release.

The version is the one [gmtask](https://github.com/ctx42/gmtask) derives for
every ctx42 project, so both build paths tag the images identically; see
[gitaid's versioning
scheme](https://github.com/ctx42/gitaid/blob/master/docs/versioning.md).

## Push Images

Log in to the registry first (`docker login ghcr.io`), then push what was just
built:

```shell
gomake :docker:image:push -n dkigo -l        # push all targets, and a release's latest
gomake :docker:image:push -n dkigo -T base   # push only the given target(s)
```

Without gomake, [`bin/push.sh`](bin/push.sh) pushes the images built by
`bin/build.sh`, reusing the same targets and the same `cmd/scmver` derivation
so `./bin/build.sh && ./bin/push.sh` publishes the versioned tags that were
just built. It does not push `latest`; for a release, build with
`C42_BLD_PUSH=1` instead, which pushes both:

```shell
./bin/push.sh           # push all targets in C42_BLD_IMG_TARGETS
./bin/push.sh base      # push only the given target(s)
```
