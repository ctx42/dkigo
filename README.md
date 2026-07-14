# Go Docker Images.

Package provides base images for Go projects:

- ghcr.io/ctx42/dkigo-base:vX.Y.Z — tiny runtime base on AlmaLinux micro.
- ghcr.io/ctx42/dkigo-test:vX.Y.Z — full build/test image on AlmaLinux minimal.

## Build Images

The images build straight from `configs/project.conf` — no extra tooling
required. [`bin/build.sh`](bin/build.sh) sources that file for every build
argument (versions, paths, registry) and derives the OCI label metadata from
git.

```shell
./bin/build.sh          # build all targets in C42_BLD_TARGETS
./bin/build.sh base     # build only the given target(s)
```

Each image is tagged `$C42_REG_REPO/dkigo-<target>:<git-describe>`.

## Push Images

[`bin/push.sh`](bin/push.sh) pushes the images built by `bin/build.sh`, reusing
the same targets and git-describe tag so `./bin/build.sh && ./bin/push.sh`
publishes exactly what was just built. Log in to the registry first
(`docker login ghcr.io`).

```shell
./bin/push.sh           # push all targets in C42_BLD_TARGETS
./bin/push.sh base      # push only the given target(s)
```
