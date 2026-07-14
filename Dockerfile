# ==============================================================================
# Creates "base" and "test" images for Go programs.
#
#   base - tiny runtime base on almalinux micro (no toolchain, no package
#          manager); this is what deployable services build FROM.
#   test - full build/test image on almalinux minimal, adding the Go toolchain
#          on top of the "src-base"/"src-test" intermediates.
#
# "src-base" and "src-test" are intermediates for the test image - use "test".
# ==============================================================================
ARG C42_BLD_IMG_BASE
ARG C42_BLD_IMG_MICRO
FROM $C42_BLD_IMG_BASE AS src-base

# Configure private repositories.
COPY <<-EOF /etc/gitconfig
  [url "git@github.com:"]
  insteadOf = https://github.com/
  [url "git@bitbucket.org:"]
  insteadOf = https://bitbucket.org/
EOF

# Defines root directory.
ARG C42_CTR_ROOT=/ctx42

# Project directory. This is where you should bind or copy project files.
ARG C42_CTR_PROJECT_ROOT=$C42_CTR_ROOT/project

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
    C42_CTR_PROJECT_ROOT=$C42_CTR_PROJECT_ROOT \
    GOPATH=$C42_BLD_GOPATH \
    GOCACHE=$C42_BLD_GOCACHE \
    GOBIN=$C42_BLD_GOBIN \
    C42_CTR_BIN=$C42_CTR_BIN \
    GOPRIVATE=$C42_GOPRIVATE \
    C42_CTR_ENTRYPOINT=$C42_CTR_ENTRYPOINT \
    PATH="$PATH:/usr/local/go/bin:$C42_BLD_GOBIN:$C42_CTR_BIN"

RUN mkdir -p $C42_CTR_ROOT && \
    chmod go+rwx $C42_CTR_ROOT && \
    mkdir -p $C42_CTR_PROJECT_ROOT && \
    chmod go+rwx $C42_CTR_PROJECT_ROOT && \
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

COPY scripts/keep_ctr_alive.sh $C42_CTR_BIN
COPY scripts/run_scripts.sh $C42_CTR_BIN

WORKDIR $C42_CTR_PROJECT_ROOT

# ==============================================================================
# Creates image with compilation and test tools.
# NOTE: The created image is not intended to be used directly use "test" image.
# ==============================================================================
FROM src-base AS src-test

RUN microdnf -y install wget tar openssh-clients && \
    microdnf -y clean all

ARG C42_BLD_GO_VERSION
RUN --mount=type=ssh ssh-keyscan -t rsa github.com bitbucket.org >> /etc/ssh/ssh_known_hosts && \
    wget "https://dl.google.com/go/go$C42_BLD_GO_VERSION.linux-amd64.tar.gz" -O go.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz

# Go private repository location.
ARG C42_GOPRIVATE="github.com/ctx42"

# Configure private repositories.
COPY <<-EOF /etc/gitconfig
  [url "git@github.com:"]
  insteadOf = https://github.com/
  [url "git@bitbucket.org:"]
  insteadOf = https://bitbucket.org/
EOF

# Defines root directory.
ARG C42_CTR_ROOT=/ctx42

# Project directory. This is where you should bind or copy project files.
ARG C42_CTR_PROJECT_ROOT=$C42_CTR_ROOT/project

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
    C42_CTR_PROJECT_ROOT=$C42_CTR_PROJECT_ROOT \
    GOPATH=$C42_BLD_GOPATH \
    GOCACHE=$C42_BLD_GOCACHE \
    GOBIN=$C42_BLD_GOBIN \
    C42_CTR_BIN=$C42_CTR_BIN \
    GOPRIVATE=$C42_GOPRIVATE \
    C42_CTR_ENTRYPOINT=$C42_CTR_ENTRYPOINT \
    PATH="$PATH:/usr/local/go/bin:$C42_BLD_GOBIN:$C42_CTR_BIN"

WORKDIR $C42_CTR_PROJECT_ROOT

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

# Go module proxy address.
ARG C42_GOPROXY=https://proxy.golang.org

# Go checksum database.
ARG C42_GOSUMDB="sum.golang.org"

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

# Pull the shared golangci-lint configuration. It lives at the container root so
# golangci-lint auto-discovers it from $C42_CTR_PROJECT_ROOT as a fallback when a
# project provides no .golangci.yml of its own.
ARG C42_BLD_XDEV_VERSION
RUN wget https://raw.githubusercontent.com/ctx42/xdev/$C42_BLD_XDEV_VERSION/.golangci.yml -O $C42_CTR_ROOT/.golangci.yml

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
# Supplies the runtime artifacts the micro base lacks: the CA trust store and a
# static tini. Runs on minimal only because it needs a package manager; nothing
# ships from here except the two artifacts copied into "base".
# ==============================================================================
FROM $C42_BLD_IMG_BASE AS base-builder

ARG C42_BLD_TINI_VERSION
RUN microdnf -y install ca-certificates wget && \
    wget https://github.com/krallin/tini/releases/download/$C42_BLD_TINI_VERSION/tini-static-amd64 -O /tini && \
    chmod +x /tini && \
    microdnf -y clean all

# ==============================================================================
# Tiny runtime base on almalinux micro. Micro ships bash, coreutils and tzdata
# but no package manager and no CA store; the CA store and tini come from
# "base-builder". Do not add microdnf here - there is none.
# NOTE: This is the image you want to use instead of "src-base".
# ==============================================================================
FROM $C42_BLD_IMG_MICRO AS base

# Configure private repositories (kept for parity with the test image).
COPY <<-EOF /etc/gitconfig
  [url "git@github.com:"]
  insteadOf = https://github.com/
  [url "git@bitbucket.org:"]
  insteadOf = https://bitbucket.org/
EOF

# Defines root directory.
ARG C42_CTR_ROOT=/ctx42

# Project directory. This is where you should bind or copy project files.
ARG C42_CTR_PROJECT_ROOT=$C42_CTR_ROOT/project

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
    C42_CTR_PROJECT_ROOT=$C42_CTR_PROJECT_ROOT \
    GOPATH=$C42_BLD_GOPATH \
    GOCACHE=$C42_BLD_GOCACHE \
    GOBIN=$C42_BLD_GOBIN \
    C42_CTR_BIN=$C42_CTR_BIN \
    GOPRIVATE=$C42_GOPRIVATE \
    C42_CTR_ENTRYPOINT=$C42_CTR_ENTRYPOINT \
    PATH="$PATH:/usr/local/go/bin:$C42_BLD_GOBIN:$C42_CTR_BIN"

RUN mkdir -p $C42_CTR_ROOT && chmod go+rwx $C42_CTR_ROOT && \
    mkdir -p $C42_CTR_PROJECT_ROOT && chmod go+rwx $C42_CTR_PROJECT_ROOT && \
    mkdir -p $C42_BLD_GOPATH && chmod go+rwx $C42_BLD_GOPATH && \
    mkdir -p $C42_BLD_GOBIN && chmod go+rwx $C42_BLD_GOBIN && \
    mkdir -p $C42_CTR_BIN && chmod go+rwx $C42_CTR_BIN && \
    mkdir -p $C42_CTR_ENTRYPOINT && chmod go+rwx $C42_CTR_ENTRYPOINT && \
    mkdir -p $C42_BLD_GOCACHE && chmod go+rwx $C42_BLD_GOCACHE && \
    mkdir -p $HOME/.ssh && chmod og-rwx $HOME/.ssh && \
    mkdir -p /etc/profile.d && \
    echo 'alias ll="ls -al"' >> /etc/profile.d/ctx42.sh

# Runtime artifacts micro lacks: the CA trust store and a static init.
COPY --from=base-builder /etc/pki /etc/pki
COPY --from=base-builder /tini $C42_CTR_BIN/tini

COPY scripts/keep_ctr_alive.sh $C42_CTR_BIN
COPY scripts/run_scripts.sh $C42_CTR_BIN

WORKDIR $C42_CTR_PROJECT_ROOT

# ctx42 arguments expected in all Dockerfiles.
ARG C42_BUILD_DATE="0001-01-01T00:00:00Z"
ARG C42_CCID="unknown"
ARG C42_SCM_REPO="unknown"
ARG C42_SCM_HASH="0000000"
ARG C42_SCM_REV="v0.0.0"

# OCI Image Spec labels expected to be set in all images.
LABEL org.opencontainers.image.created="$C42_BUILD_DATE" \
      org.opencontainers.image.ref.name="$C42_CCID" \
      org.opencontainers.image.source="$C42_SCM_REPO" \
      org.opencontainers.image.revision="$C42_SCM_HASH" \
      org.opencontainers.image.version="$C42_SCM_REV"

# ctx42 and OCI environment variables expected in all images.
ENV C42_BUILD_DATE="$C42_BUILD_DATE" \
    C42_CCID="$C42_CCID" \
    C42_SCM_REPO="$C42_SCM_REPO" \
    C42_SCM_HASH="$C42_SCM_HASH" \
    C42_SCM_REV="$C42_SCM_REV" \
    OCI_IMAGE_CREATED="$C42_BUILD_DATE" \
    OCI_IMAGE_REF_NAME="$C42_CCID" \
    OCI_IMAGE_SOURCE="$C42_SCM_REPO" \
    OCI_IMAGE_REVISION="$C42_SCM_HASH" \
    OCI_IMAGE_VERSION="$C42_SCM_REV" \
    TZ="UTC"


# ==============================================================================
# Image adds all required tags and labels to "src-test" image.
# NOTE: This is the image you want to use instead of "src-test".
# ==============================================================================
FROM src-test AS test

# ctx42 arguments expected in all Dockerfiles.
ARG C42_BUILD_DATE="0001-01-01T00:00:00Z"
ARG C42_CCID="unknown"
ARG C42_SCM_REPO="unknown"
ARG C42_SCM_HASH="0000000"
ARG C42_SCM_REV="v0.0.0"

# OCI Image Spec labels expected to be set in all images.
LABEL org.opencontainers.image.created="$C42_BUILD_DATE" \
      org.opencontainers.image.ref.name="$C42_CCID" \
      org.opencontainers.image.source="$C42_SCM_REPO" \
      org.opencontainers.image.revision="$C42_SCM_HASH" \
      org.opencontainers.image.version="$C42_SCM_REV"

# ctx42 and OCI environment variables expected in all images.
ENV C42_BUILD_DATE="$C42_BUILD_DATE" \
    C42_CCID="$C42_CCID" \
    C42_SCM_REPO="$C42_SCM_REPO" \
    C42_SCM_HASH="$C42_SCM_HASH" \
    C42_SCM_REV="$C42_SCM_REV" \
    OCI_IMAGE_CREATED="$C42_BUILD_DATE" \
    OCI_IMAGE_REF_NAME="$C42_CCID" \
    OCI_IMAGE_SOURCE="$C42_SCM_REPO" \
    OCI_IMAGE_REVISION="$C42_SCM_HASH" \
    OCI_IMAGE_VERSION="$C42_SCM_REV" \
    TZ="UTC"
