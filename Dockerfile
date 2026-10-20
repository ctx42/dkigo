# check=skip=InvalidDefaultArgInFrom
# ==============================================================================
# Creates "base" and "test" images for Go programs.
#
# The base images come from C42_BLD_IMG_BASE and C42_BLD_IMG_RUNTIME, which
# bin/build.sh always passes from configs/project.conf. They have no defaults
# here so the two cannot drift, hence the skipped check above.
#
#   base - runtime base on almalinux minimal (no toolchain; microdnf and
#          useradd for the services' own stages); this is what deployable
#          services build FROM.
#   test - full build/test image on almalinux minimal, adding the Go toolchain
#          on top of the "src-base"/"src-test" intermediates.
#
# "src-base" and "src-test" are intermediates for the test image - use "test".
#
# Both images trust the CA certificates of the project building them, read
# from configs/ca/*.crt in the "project" build context through "project-ca".
# ==============================================================================
ARG C42_BLD_IMG_BASE
ARG C42_BLD_IMG_RUNTIME

# ==============================================================================
# Files of the project building the images. gomake passes the project as the
# "project" named build context when it builds from this Dockerfile as a Go
# module, which replaces this empty stage; any other build sees no files.
# ==============================================================================
FROM scratch AS project

# ==============================================================================
# The project's CA certificates, configs/ca/*.crt, alone in /ca. Only this
# stage reads the whole "project" context, which changes with any file of the
# project. The images mount /ca from here, and a mount with a source is cached
# on that path's content, so their layers stay cached until a certificate
# changes.
# ==============================================================================
FROM $C42_BLD_IMG_BASE AS project-ca

RUN --mount=type=bind,from=project,target=/project \
    mkdir /ca && \
    set -- /project/configs/ca/*.crt && \
    if [ -e "$1" ]; then \
        cp "$@" /ca/; \
    fi

FROM $C42_BLD_IMG_BASE AS src-base

# Trust the project's CA certificates, from "project-ca", before anything is
# downloaded, so a TLS-intercepting proxy works too. Without any, the trust
# store is left as it is.
RUN --mount=type=bind,from=project-ca,source=/ca,target=/ca \
    set -- /ca/*.crt && \
    if [ -e "$1" ]; then \
        cp "$@" /etc/pki/ca-trust/source/anchors/ && \
        update-ca-trust extract; \
    fi

# Reach the C42_BLD_GIT_SSH_HOSTS git hosts over SSH: rewrite each
# https://<host>/ to git@<host>:.
ARG C42_BLD_GIT_SSH_HOSTS
RUN IFS=, && for host in $C42_BLD_GIT_SSH_HOSTS; do \
        printf '[url "git@%s:"]\n\tinsteadOf = https://%s/\n' "$host" "$host" >> /etc/gitconfig; \
    done

# Defines root directory.
ARG C42_CTR_ROOT=/ctx42

# Project directory. This is where you should bind or copy project files.
ARG C42_CTR_PRJ_ROOT=$C42_CTR_ROOT/project

# The directory to point GOPATH to.
ARG C42_BLD_GOPATH=$C42_CTR_ROOT/go

# The directory to point GOCACHE to.
ARG C42_BLD_GOCACHE=$C42_CTR_ROOT/go-cache

# The directory to point GOBIN to.
ARG C42_BLD_GOBIN=$C42_CTR_ROOT/go-bin

# The directory with VR binaries or scripts.
ARG C42_CTR_BIN=$C42_CTR_ROOT/bin

# The directory with container entrypoint files.
ARG C42_CTR_ENTRYPOINT=$C42_CTR_ROOT/entrypoint

# Go private repository location.
ARG C42_GOPRIVATE="github.com/ctx42"

ENV C42_CTR_ROOT=$C42_CTR_ROOT \
    C42_CTR_PRJ_ROOT=$C42_CTR_PRJ_ROOT \
    GOPATH=$C42_BLD_GOPATH \
    GOCACHE=$C42_BLD_GOCACHE \
    GOBIN=$C42_BLD_GOBIN \
    C42_CTR_BIN=$C42_CTR_BIN \
    GOPRIVATE=$C42_GOPRIVATE \
    C42_CTR_ENTRYPOINT=$C42_CTR_ENTRYPOINT \
    PATH="$PATH:/usr/local/go/bin:$C42_BLD_GOBIN:$C42_CTR_BIN"

RUN mkdir -p $C42_CTR_ROOT && \
    chmod go+rwx $C42_CTR_ROOT && \
    mkdir -p $C42_CTR_PRJ_ROOT && \
    chmod go+rwx $C42_CTR_PRJ_ROOT && \
    mkdir -p $C42_BLD_GOPATH && \
    chmod go+rwx $C42_BLD_GOPATH && \
    mkdir -p $C42_BLD_GOBIN && \
    chmod go+rwx $C42_BLD_GOBIN && \
    mkdir -p $C42_CTR_BIN && \
    chmod go+rwx $C42_CTR_BIN && \
    mkdir -p $C42_CTR_ENTRYPOINT && \
    chmod go+rwx $C42_CTR_ENTRYPOINT && \
    mkdir -p $C42_BLD_GOCACHE && \
    chmod go+rwx $C42_BLD_GOCACHE && \
    mkdir $HOME/.ssh && \
    chmod og-rwx $HOME/.ssh && \
    echo 'alias ll="ls -al"' >> /etc/profile.d/ctx42.sh

ARG C42_BLD_TINI_VERSION
RUN microdnf -y install wget && \
    wget https://github.com/krallin/tini/releases/download/$C42_BLD_TINI_VERSION/tini-static-amd64 -O $C42_CTR_BIN/tini && \
    chmod +x $C42_CTR_BIN/tini && \
    microdnf -y clean all

# Set the mode: a build from the Go module cache gets read-only files.
COPY --chmod=0755 scripts/keep_ctr_alive.sh $C42_CTR_BIN
COPY --chmod=0755 scripts/run_scripts.sh $C42_CTR_BIN

WORKDIR $C42_CTR_PRJ_ROOT

# ==============================================================================
# Creates image with compilation and test tools.
# NOTE: The created image is not intended to be used directly use "test" image.
# ==============================================================================
FROM src-base AS src-test

RUN microdnf -y install wget tar openssh-clients && \
    microdnf -y clean all

# Trust the RSA keys of the C42_BLD_GIT_SSH_HOSTS git hosts; /etc/gitconfig
# rewriting them to SSH comes from "src-base".
ARG C42_BLD_GIT_SSH_HOSTS
RUN --mount=type=ssh IFS=, && set -- $C42_BLD_GIT_SSH_HOSTS && \
    if [ $# -gt 0 ]; then \
        ssh-keyscan -t rsa "$@" >> /etc/ssh/ssh_known_hosts; \
    fi

ARG C42_BLD_GO_VERSION
RUN wget "https://dl.google.com/go/go$C42_BLD_GO_VERSION.linux-amd64.tar.gz" -O go.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz

# Go private repository location.
ARG C42_GOPRIVATE="github.com/ctx42"

# Defines root directory.
ARG C42_CTR_ROOT=/ctx42

# Project directory. This is where you should bind or copy project files.
ARG C42_CTR_PRJ_ROOT=$C42_CTR_ROOT/project

# The directory to point GOPATH to.
ARG C42_BLD_GOPATH=$C42_CTR_ROOT/go

# The directory to point GOCACHE to.
ARG C42_BLD_GOCACHE=$C42_CTR_ROOT/go-cache

# The directory to point GOBIN to.
ARG C42_BLD_GOBIN=$C42_CTR_ROOT/go-bin

# The directory with VR binaries or scripts.
ARG C42_CTR_BIN=$C42_CTR_ROOT/bin

# The directory with container entrypoint files.
ARG C42_CTR_ENTRYPOINT=$C42_CTR_ROOT/entrypoint

ENV C42_CTR_ROOT=$C42_CTR_ROOT \
    C42_CTR_PRJ_ROOT=$C42_CTR_PRJ_ROOT \
    GOPATH=$C42_BLD_GOPATH \
    GOCACHE=$C42_BLD_GOCACHE \
    GOBIN=$C42_BLD_GOBIN \
    C42_CTR_BIN=$C42_CTR_BIN \
    GOPRIVATE=$C42_GOPRIVATE \
    C42_CTR_ENTRYPOINT=$C42_CTR_ENTRYPOINT

WORKDIR $C42_CTR_PRJ_ROOT

RUN microdnf -y install shadow-utils vim bash-completion gcc gcc-c++ kernel-devel make gzip xz curl-minimal git && \
    microdnf -y clean all

# Install docker client.
ARG C42_BLD_DOCKER_CLI_VERSION
RUN cd /tmp && \
    curl -L https://download.docker.com/linux/static/stable/x86_64/docker-$C42_BLD_DOCKER_CLI_VERSION.tgz | tar -xz docker && \
    mv docker/docker /usr/local/bin/docker && \
    rm -rf /tmp/docker

# Install Docker buildx plugin.
ARG C42_BLD_DOCKER_BUILDX_VERSION
RUN cd /tmp && \
    wget https://github.com/docker/buildx/releases/download/$C42_BLD_DOCKER_BUILDX_VERSION/buildx-$C42_BLD_DOCKER_BUILDX_VERSION.linux-amd64 && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    mv buildx-$C42_BLD_DOCKER_BUILDX_VERSION.linux-amd64 /usr/local/lib/docker/cli-plugins/docker-buildx && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Path to golintci cache directory.
ARG C42_BLD_GOLINT_CACHE=$C42_CTR_ROOT/go-cache-lint

ENV GOLANGCI_LINT_CACHE=$C42_BLD_GOLINT_CACHE \
    CGO_ENABLED=1

# The golangci-lint version to install.
ARG C42_BLD_GOLANGCI_LINT_VERSION

# Install tools.
RUN CGO_ENABLED=0 go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$C42_BLD_GOLANGCI_LINT_VERSION && \
    go install golang.org/x/tools/cmd/godoc@latest && \
    go install github.com/jstemmer/go-junit-report/v2@latest && \
    go install github.com/boumenot/gocover-cobertura@latest && \
    rm -rf $GOPATH/* && rm -rf $GOCACHE/*

# Pull the shared golangci-lint configuration from C42_BLD_GOLINT_CONFIG, in
# either form gomake's :go:lint:config takes: an https URL whose path does not
# end in ".git" is the file itself, any other value a git repository whose
# default branch holds .golangci.yml; empty installs none. It lives at the
# container root so golangci-lint auto-discovers it from $C42_CTR_PRJ_ROOT as a
# fallback when a project provides no .golangci.yml of its own.
ARG C42_BLD_GOLINT_CONFIG
RUN --mount=type=ssh src="$C42_BLD_GOLINT_CONFIG" && \
    if [ -z "$src" ]; then \
        true; \
    elif [ "${src#https://}" != "$src" ] && [ "${src%.git}" = "$src" ]; then \
        wget "$src" -O $C42_CTR_ROOT/.golangci.yml; \
    else \
        git clone --depth 1 --single-branch --no-tags "$src" /tmp/golint && \
        cp /tmp/golint/.golangci.yml $C42_CTR_ROOT/.golangci.yml && \
        rm -rf /tmp/golint; \
    fi

# Install the gomake tool with gmtask's targets compiled in. gomake and gmtask
# are public, so override the private-repo GOPRIVATE to fetch them through the
# module proxy instead of direct git over SSH. When targets are requested the
# installer resolves the target packages with `go list` in the current
# directory, so run it from a throwaway module with -mod=mod; the plain install
# (empty C42_BLD_GMTASK_VERSION) builds from the read-only module cache and must
# not force -mod=mod.
ARG C42_BLD_GOMAKE_VERSION
ARG C42_BLD_GMTASK_VERSION
RUN export GOPRIVATE= && \
    if [ -n "$C42_BLD_GMTASK_VERSION" ]; then \
        mkdir -p /tmp/gomake-install && cd /tmp/gomake-install && \
        go mod init gomake-install && \
        GOFLAGS=-mod=mod go run github.com/ctx42/gomake/cmd/install@$C42_BLD_GOMAKE_VERSION \
            --targets=https://raw.githubusercontent.com/ctx42/gmtask/$C42_BLD_GMTASK_VERSION/targets.yaml; \
    else \
        go run github.com/ctx42/gomake/cmd/install@$C42_BLD_GOMAKE_VERSION; \
    fi && \
    cd / && rm -rf /tmp/gomake-install $GOPATH/* $GOCACHE/*

# ==============================================================================
# Supplies the runtime artifacts of "base": the CA trust store with the
# project's certificates and a static tini. Nothing ships from here except the
# two artifacts copied into "base".
# ==============================================================================
FROM $C42_BLD_IMG_BASE AS base-builder

# Trust the project's CA certificates, from "project-ca", before anything is
# downloaded, so a TLS-intercepting proxy works too. Without any, the trust
# store is left as it is.
RUN --mount=type=bind,from=project-ca,source=/ca,target=/ca \
    set -- /ca/*.crt && \
    if [ -e "$1" ]; then \
        cp "$@" /etc/pki/ca-trust/source/anchors/ && \
        update-ca-trust extract; \
    fi

ARG C42_BLD_TINI_VERSION
RUN microdnf -y install ca-certificates wget && \
    wget https://github.com/krallin/tini/releases/download/$C42_BLD_TINI_VERSION/tini-static-amd64 -O /tini && \
    chmod +x /tini && \
    microdnf -y clean all

# ==============================================================================
# Runtime base on almalinux minimal: bash, coreutils, tzdata, microdnf and
# shadow-utils, so a service's own stage can install packages and add its
# user; the CA store and tini come from "base-builder".
# NOTE: This is the image you want to use instead of "src-base".
# ==============================================================================
FROM $C42_BLD_IMG_RUNTIME AS base

# Reach the C42_BLD_GIT_SSH_HOSTS git hosts over SSH (kept for parity with the
# test image): rewrite each https://<host>/ to git@<host>:.
ARG C42_BLD_GIT_SSH_HOSTS
RUN IFS=, && for host in $C42_BLD_GIT_SSH_HOSTS; do \
        printf '[url "git@%s:"]\n\tinsteadOf = https://%s/\n' "$host" "$host" >> /etc/gitconfig; \
    done

# Defines root directory.
ARG C42_CTR_ROOT=/ctx42

# Project directory. This is where you should bind or copy project files.
ARG C42_CTR_PRJ_ROOT=$C42_CTR_ROOT/project

# The directory to point GOPATH to.
ARG C42_BLD_GOPATH=$C42_CTR_ROOT/go

# The directory to point GOCACHE to.
ARG C42_BLD_GOCACHE=$C42_CTR_ROOT/go-cache

# The directory to point GOBIN to.
ARG C42_BLD_GOBIN=$C42_CTR_ROOT/go-bin

# The directory with VR binaries or scripts.
ARG C42_CTR_BIN=$C42_CTR_ROOT/bin

# The directory with container entrypoint files.
ARG C42_CTR_ENTRYPOINT=$C42_CTR_ROOT/entrypoint

# Go private repository location.
ARG C42_GOPRIVATE="github.com/ctx42"

ENV C42_CTR_ROOT=$C42_CTR_ROOT \
    C42_CTR_PRJ_ROOT=$C42_CTR_PRJ_ROOT \
    GOPATH=$C42_BLD_GOPATH \
    GOCACHE=$C42_BLD_GOCACHE \
    GOBIN=$C42_BLD_GOBIN \
    C42_CTR_BIN=$C42_CTR_BIN \
    GOPRIVATE=$C42_GOPRIVATE \
    C42_CTR_ENTRYPOINT=$C42_CTR_ENTRYPOINT \
    PATH="$PATH:/usr/local/go/bin:$C42_BLD_GOBIN:$C42_CTR_BIN"

RUN mkdir -p $C42_CTR_ROOT && chmod go+rwx $C42_CTR_ROOT && \
    mkdir -p $C42_CTR_PRJ_ROOT && chmod go+rwx $C42_CTR_PRJ_ROOT && \
    mkdir -p $C42_BLD_GOPATH && chmod go+rwx $C42_BLD_GOPATH && \
    mkdir -p $C42_BLD_GOBIN && chmod go+rwx $C42_BLD_GOBIN && \
    mkdir -p $C42_CTR_BIN && chmod go+rwx $C42_CTR_BIN && \
    mkdir -p $C42_CTR_ENTRYPOINT && chmod go+rwx $C42_CTR_ENTRYPOINT && \
    mkdir -p $C42_BLD_GOCACHE && chmod go+rwx $C42_BLD_GOCACHE && \
    mkdir -p $HOME/.ssh && chmod og-rwx $HOME/.ssh && \
    mkdir -p /etc/profile.d && \
    echo 'alias ll="ls -al"' >> /etc/profile.d/ctx42.sh

# The CA trust store with the project's certificates and a static init.
COPY --from=base-builder /etc/pki /etc/pki
COPY --from=base-builder /tini $C42_CTR_BIN/tini

# Set the mode: a build from the Go module cache gets read-only files.
COPY --chmod=0755 scripts/keep_ctr_alive.sh $C42_CTR_BIN
COPY --chmod=0755 scripts/run_scripts.sh $C42_CTR_BIN

WORKDIR $C42_CTR_PRJ_ROOT

# ctx42 arguments expected in all Dockerfiles.
ARG C42_BLD_DATE="0001-01-01T00:00:00Z"
ARG C42_SCM_REPO="unknown"
ARG C42_SCM_HASH="0000000"
ARG C42_SCM_REV="v0.0.0"

# OCI Image Spec labels expected to be set in all images.
LABEL org.opencontainers.image.created="$C42_BLD_DATE" \
      org.opencontainers.image.ref.name="$C42_SCM_REV" \
      org.opencontainers.image.source="$C42_SCM_REPO" \
      org.opencontainers.image.revision="$C42_SCM_HASH" \
      org.opencontainers.image.version="$C42_SCM_REV"

# ctx42 environment variables expected in all images. The OCI metadata is
# carried by the labels above only; xdef dropped the OCI_IMAGE_* variables
# that used to mirror them.
ENV C42_BLD_DATE="$C42_BLD_DATE" \
    C42_SCM_REPO="$C42_SCM_REPO" \
    C42_SCM_HASH="$C42_SCM_HASH" \
    C42_SCM_REV="$C42_SCM_REV" \
    TZ="UTC"


# ==============================================================================
# Image adds all required tags and labels to "src-test" image.
# NOTE: This is the image you want to use instead of "src-test".
# ==============================================================================
FROM src-test AS test

# ctx42 arguments expected in all Dockerfiles.
ARG C42_BLD_DATE="0001-01-01T00:00:00Z"
ARG C42_SCM_REPO="unknown"
ARG C42_SCM_HASH="0000000"
ARG C42_SCM_REV="v0.0.0"

# OCI Image Spec labels expected to be set in all images.
LABEL org.opencontainers.image.created="$C42_BLD_DATE" \
      org.opencontainers.image.ref.name="$C42_SCM_REV" \
      org.opencontainers.image.source="$C42_SCM_REPO" \
      org.opencontainers.image.revision="$C42_SCM_HASH" \
      org.opencontainers.image.version="$C42_SCM_REV"

# Unlike the runtime base, the build image does not export its own build
# metadata: gomake reads C42_BLD_DATE from the environment, so a build run in
# this image would stamp the image's build date into what it builds. The
# labels above describe the image.
ENV TZ="UTC"

# Go module proxy and checksum database for the go command run in the image.
# Set in this final stage so the tool installs above always use the go
# defaults. An empty value - the configs/project.conf default - is the same as
# unset: the go command falls back to proxy.golang.org and sum.golang.org.
ARG C42_GOPROXY=""
ARG C42_GOSUMDB=""
ENV GOPROXY="$C42_GOPROXY" \
    GOSUMDB="$C42_GOSUMDB"

# CI runs the image as the agent's own user, which has no account here and so
# gets "/" as its home. Give any user a writable home, so the docker, git, and
# Go tools can keep their state there, and create the golangci-lint cache. Set
# last, so no build step above leaves root-owned files in that home.
RUN mkdir -p -m 1777 "$C42_CTR_ROOT/home" && \
    mkdir -p "$GOLANGCI_LINT_CACHE" && \
    chmod go+rwx "$GOLANGCI_LINT_CACHE"
ENV HOME="$C42_CTR_ROOT/home"
