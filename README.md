# Go Docker Images.

Package provides base images for Go projects:

- ghcr.io/ctx42/dkigo-base:vX.Y.Z — tiny runtime base on AlmaLinux micro.
- ghcr.io/ctx42/dkigo-test:vX.Y.Z — full build/test image on AlmaLinux minimal.

## Build Images

The images build straight from `configs/project.conf` — no tooling beyond Go
and Docker required. [`bin/build.sh`](bin/build.sh) sources that file for
every build argument (versions, paths, registry) and takes the version and OCI
label metadata from [`cmd/scmver`](cmd/scmver), which it compiles and runs.

```shell
./bin/build.sh          # build all targets in C42_BLD_IMG_TARGETS
./bin/build.sh base     # build only the given target(s)
```

Each image is tagged `$C42_REG_REPO/dkigo-<target>:<version>`, where the
version comes from the git state: a clean checkout of a semver tag builds
`v0.4.0`, anything else builds a pre-release of the next release, such as
`v0.5.0-dev.3.dirty_g7f93fb4`. Which release that is — patch, minor or
major — is read off the Conventional Commits since the tag, and
`C42_BLD_BUMP` overrides it. Untracked files count as changes and make a
build dirty. Only a release is additionally tagged `latest`, and a
pre-release tag such as `v1.0.0-rc.1` is not a release.

The version is the one [gmtask](https://github.com/ctx42/gmtask) derives for
every ctx42 project, pinned by `go.mod`; see [gitaid's versioning
scheme](https://github.com/ctx42/gitaid/blob/master/docs/versioning.md).

## Push Images

[`bin/push.sh`](bin/push.sh) pushes the images built by `bin/build.sh`, reusing
the same targets and the same `cmd/scmver` derivation so
`./bin/build.sh && ./bin/push.sh` publishes exactly what was just built. Log
in to the registry first (`docker login ghcr.io`).

```shell
./bin/push.sh           # push all targets in C42_BLD_IMG_TARGETS
./bin/push.sh base      # push only the given target(s)
```
