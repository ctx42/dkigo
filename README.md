# Go Docker Images.

Package provides base images for Go projects:

- ghcr.io/ctx42/dkigo-base:vX.Y.Z — runtime base on AlmaLinux minimal.
- ghcr.io/ctx42/dkigo-test:vX.Y.Z — full build/test image on AlmaLinux minimal.

## Build Images

The preferred way to build and push the images is
[gomake](https://github.com/ctx42/gomake) with the `:docker:*` targets from
[gmtask](https://github.com/ctx42/gmtask) compiled in — the same tool every
ctx42 project builds its images with. From the repository root, install the
versions `configs/project.conf` pins:

```shell
eval "$(grep -E '^C42_BLD_(GOMAKE|GMTASK)_VERSION=' configs/project.conf)"
raw=https://raw.githubusercontent.com/ctx42/gmtask
cd "$(mktemp -d)" && go mod init gomake-install
GOFLAGS=-mod=mod go run \
    github.com/ctx42/gomake/cmd/install@$C42_BLD_GOMAKE_VERSION \
    --targets=$raw/$C42_BLD_GMTASK_VERSION/targets.yaml
cd -
```

Then, from the repository root:

```shell
gomake :docker:image:build -n dkigo -l       # build all targets in C42_BLD_IMG_TARGETS
gomake :docker:image:build -n dkigo -T base  # build only the given target(s)
gomake :docker:image:build -n dkigo -l -d    # print the docker commands, run nothing
```

`-n` sets the image name and is optional. Without it, gomake derives the name
from the repository directory (`C42_PRJ_NAME`) and prefixes it with `dki-`,
unless it already starts with `dki-` or contains `-dki-`. The dkigo images are
published as `dkigo-<target>`, so building in this repository takes
`-n dkigo`; without it they would be `dki-dkigo-<target>`. `-l` also tags a
release `latest` (see [Image Tags](#image-tags)).

### Without gomake

Use gomake when you can. If you don't have it, [`bin/build.sh`](bin/build.sh)
is the fallback: it builds the same images, with the same build arguments and
tags, using nothing but Go and Docker. It compiles and runs
[`cmd/cfgenv`](cmd/cfgenv), which resolves `configs/project.conf` and the
environment overrides the way gomake does, for every build argument (versions,
paths, registry), and [`cmd/scmver`](cmd/scmver) for the version and OCI label
metadata — the same gmtask code gomake uses, pinned by `go.mod`. It then runs
`docker buildx build` once per target and tags `latest` automatically for a
release. Its log output differs from gomake's.

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
so `./bin/build.sh && ./bin/push.sh` publishes exactly what was just built,
including `latest` for a release:

```shell
./bin/push.sh           # push all targets in C42_BLD_IMG_TARGETS
./bin/push.sh base      # push only the given target(s)
```

## Another Registry

The registry in `configs/project.conf` is ctx42's. To build and publish the
images under your own organization without forking, override it from the
environment: a variable named like a key in `configs/project.conf` replaces
that key's value, an empty value included. Variables the file does not declare
are ignored. Overrides apply before `$VAR` expansion, so a value referring to an
overridden key follows it: overriding `C42_REG_HOST` alone also moves
`C42_REG_REPO=$C42_REG_HOST/ctx42`. Both build paths honor the override and
print one `override KEY=value` line per overridden key:

```shell
export C42_REG_HOST=registry.acme.io       # C42_REG_REPO becomes registry.acme.io/ctx42
export C42_REG_REPO=registry.acme.io/platform  # or set the repository itself
export C42_GOPRIVATE=github.com/acme

gomake :docker:image:build -n dkigo -l   # or ./bin/build.sh
gomake :docker:image:push -n dkigo -l    # or ./bin/push.sh
```

To point the `go` command in the test image at your own module proxy and
checksum database, set `C42_GOPROXY` and `C42_GOSUMDB` the same way. The test
image sets them as `GOPROXY` and `GOSUMDB`; left empty, as in
`configs/project.conf`, the `go` defaults apply. The image build itself always
fetches its tools through the defaults.

```shell
export C42_GOPROXY=https://goproxy.acme.io,direct
export C42_GOSUMDB="sum.golang.org https://goproxy.acme.io/sumdb"
```

Go code importing `github.com/ctx42/dkigo` sees the same values: `CfgGet`,
`CfgLookup`, and `CfgAll` apply the overrides from the process environment the
same way, read once on first use.

## Build from Your Own Project

Instead of building in a dkigo checkout, an organization can keep a small
project of its own that builds images from the dkigo `Dockerfile` with its own
values. gomake supports this as a Dockerfile module build (see
[gmtask's gmdkr](https://github.com/ctx42/gmtask/tree/master/pkg/gmdkr)): the
project's `go.mod` requires `github.com/ctx42/dkigo` at the version to build
from, and its `configs/project.conf` names the module and sets only the values
that differ:

```ini
# configs/project.conf
C42_BLD_DKF_MODULE=github.com/ctx42/dkigo
C42_CTR_ROOT=/opt/acme
C42_REG_HOST=registry.acme.io
C42_REG_REPO=$C42_REG_HOST/platform
```

```go
// deps_test.go - keeps go mod tidy from dropping the requirement.
package project

import _ "github.com/ctx42/dkigo"
```

`gomake :docker:image:build` and `gomake :docker:image:push` in that project
then build dkigo's `Dockerfile` with dkigo's `configs/project.conf` under the
project's one, and tag the images after the project and its own version. No
`-n` is needed: a project in `acme-dki-go` builds `acme-dki-go-base` and
`acme-dki-go-test`.

### CA Certificates

Both images trust the CA certificates the project keeps in `configs/ca/*.crt`,
for example the CA of a registry, a module proxy, or a TLS-intercepting proxy.
They are added to the trust store before the image build downloads anything,
so `microdnf`, `wget`, `curl`, `git`, `go`, and `docker` in the images all
trust them. Without the directory, or with no `.crt` file in it, the trust
store is the one the base image ships.

```text
configs/
├── ca/
│   └── acme-root.crt     # PEM certificate
└── project.conf
```

### Git Hosts over SSH

`C42_BLD_GIT_SSH_HOSTS` lists, comma-separated, the git hosts the images reach
over SSH. Both images rewrite `https://<host>/` to `git@<host>:` in
`/etc/gitconfig`, and the test image adds each host's RSA key to
`/etc/ssh/ssh_known_hosts`. The default is `github.com,bitbucket.org`; an empty
value configures no host.

```ini
# configs/project.conf
C42_BLD_GIT_SSH_HOSTS=git.acme.io
```

### Shared Lint Configuration

The test image installs a shared golangci-lint configuration as
`$C42_CTR_ROOT/.golangci.yml`, which golangci-lint finds from the project
directory when the project has no `.golangci.yml` of its own. It comes from
`C42_BLD_GOLINT_CONFIG`, the key gomake's `:go:lint:config` reads, in either of
its forms: an `https://` URL whose path does not end in `.git` is the file
itself; any other value is a git repository whose default branch holds
`.golangci.yml`, cloned over SSH when the URL or `C42_BLD_GIT_SSH_HOSTS` says
so. The default is ctx42's xdev file at `C42_BLD_XDEV_VERSION`; an empty value
installs none.

```ini
# configs/project.conf
C42_BLD_GOLINT_CONFIG=git@git.acme.io:platform/dev.git
```
