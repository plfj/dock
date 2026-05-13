# =============================================================================
# Ubuntu GitHub Actions Runner — Unified Dockerfile
# =============================================================================
# Supports: Ubuntu 22.04 (jammy) · 24.04 (noble) · 25.04 (plucky) · 26.04 (oracular)
#
# Build args:
#   UBUNTU_VERSION   — Ubuntu release number  (22.04 | 24.04 | 25.04 | 26.04)
#   UBUNTU_CODENAME  — Ubuntu codename        (jammy | noble | plucky | oracular)
#
# Example:
#   docker build --build-arg UBUNTU_VERSION=24.04 \
#                --build-arg UBUNTU_CODENAME=noble \
#                -t ghcr.io/<owner>/ubuntu-runner:24.04 .
# =============================================================================

ARG UBUNTU_VERSION=24.04
ARG UBUNTU_CODENAME=noble
ARG GITHUB_REPOSITORY=plfj/dock

# ---------------------------------------------------------------------------
# Stage 1 — base: OS packages identical to GitHub-hosted ubuntu-* runners
# ---------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS base

ARG UBUNTU_VERSION
ARG UBUNTU_CODENAME

LABEL org.opencontainers.image.title="Ubuntu ${UBUNTU_VERSION} GitHub Actions Runner" \
      org.opencontainers.image.description="Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME}) image with tooling identical to GitHub-hosted runners" \
      org.opencontainers.image.version="${UBUNTU_VERSION}" \
      org.opencontainers.image.base.name="ubuntu:${UBUNTU_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}" \
      maintainer="GitHub Actions Runner Project"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    UBUNTU_VERSION=${UBUNTU_VERSION} \
    UBUNTU_CODENAME=${UBUNTU_CODENAME}

# ---------------------------------------------------------------------------
# APT: base system upgrade + essential runtime deps
# ---------------------------------------------------------------------------
RUN apt-get update -qq && \
    apt-get upgrade -y -qq && \
    apt-get install -y --no-install-recommends \
        # Core utilities
        apt-transport-https \
        apt-utils \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget \
        # Compression & archiving
        bzip2 \
        gzip \
        p7zip-full \
        tar \
        unzip \
        xz-utils \
        zip \
        zstd \
        # Version control
        git \
        git-lfs \
        subversion \
        # Build essentials
        autoconf \
        automake \
        binutils \
        bison \
        build-essential \
        cmake \
        flex \
        g++ \
        gcc \
        libtool \
        make \
        ninja-build \
        patch \
        pkg-config \
        # Networking
        dnsutils \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        net-tools \
        openssh-client \
        socat \
        # Security & crypto
        gnupg2 \
        libssl-dev \
        openssl \
        # Shell & scripting
        bash \
        dash \
        jq \
        parallel \
        zsh \
        # Text & file tools
        file \
        gettext \
        locales \
        rsync \
        sed \
        # System monitoring
        htop \
        lsof \
        procps \
        psmisc \
        strace \
        sysstat \
        # Library development headers (commonly needed)
        libbz2-dev \
        libffi-dev \
        liblzma-dev \
        libncurses5-dev \
        libreadline-dev \
        libsqlite3-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libxslt1-dev \
        libyaml-dev \
        zlib1g-dev \
        # Container & cloud adjacent
        fuse \
        sudo \
        time \
        tzdata \
        uuid-runtime \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ---------------------------------------------------------------------------
# Stage 2 — tools: language runtimes & DevOps tooling
# ---------------------------------------------------------------------------
FROM base AS tools

ARG UBUNTU_VERSION
ARG UBUNTU_CODENAME

# ── Node.js (LTS via NodeSource) ──────────────────────────────────────────
ARG NODE_MAJOR=24
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g npm@latest yarn pnpm && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Python (system + pip + common tools) ─────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        python3-setuptools \
        python3-wheel \
        pipx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── Go ────────────────────────────────────────────────────────────────────
ARG GO_VERSION=1.26.3
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
        | tar -C /usr/local -xz && \
    ln -sf /usr/local/go/bin/go   /usr/local/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

ENV GOROOT=/usr/local/go \
    GOPATH=/root/go \
    PATH=/usr/local/go/bin:/root/go/bin:$PATH

# ── Rust ─────────────────────────────────────────────────────────────────
ENV CARGO_HOME=/opt/cargo \
    RUSTUP_HOME=/opt/rustup \
    PATH=/opt/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable && \
    /opt/cargo/bin/rustup component add clippy rustfmt && \
    chmod -R a+w /opt/cargo /opt/rustup

# ── Java (Temurin via Adoptium) ───────────────────────────────────────────
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] \
        https://packages.adoptium.net/artifactory/deb \
        $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" \
        > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends temurin-21-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/temurin-21-amd64

# ── Docker CLI (rootless-compatible) ─────────────────────────────────────
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        ${UBUNTU_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── kubectl ───────────────────────────────────────────────────────────────
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
        | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
        https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
        > /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends kubectl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Helm ──────────────────────────────────────────────────────────────────
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ── Terraform ────────────────────────────────────────────────────────────
RUN wget -qO - https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com \
        $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends terraform && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI ───────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update -qq && \
    apt-get install -y gh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── AWS CLI v2 ────────────────────────────────────────────────────────────
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# ── Azure CLI ────────────────────────────────────────────────────────────
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Google Cloud CLI ─────────────────────────────────────────────────────
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
        https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends google-cloud-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Packer ───────────────────────────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends packer && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Skopeo & Podman CLI ───────────────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends skopeo podman && \
    apt-get clean && rm -rf /var/lib/apt/lists/* || true

# ── yq ────────────────────────────────────────────────────────────────────
ARG YQ_VERSION=v4.53.2
RUN curl -fsSL \
        "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
        -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# ── GitHub Actions runner (act) ───────────────────────────────────────────
ARG ACT_VERSION=0.2.88
RUN curl -fsSL \
        "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/act_Linux_x86_64.tar.gz" \
        | tar -C /usr/local/bin -xz act && \
    chmod +x /usr/local/bin/act

# ---------------------------------------------------------------------------
# Stage 3 — final: runner user, PATH, entrypoint
# ---------------------------------------------------------------------------
FROM tools AS final

ARG UBUNTU_VERSION
ARG UBUNTU_CODENAME

# Runner user (mirrors GitHub-hosted runner UID)
RUN groupadd --gid 1001 runner && \
    useradd  --uid 1001 --gid 1001 \
             --shell /bin/bash \
             --create-home \
             --home-dir /home/runner \
             runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner && \
    chmod 440 /etc/sudoers.d/runner

# Tool directories writable by runner
RUN mkdir -p /opt/hostedtoolcache /home/runner/.local/bin && \
    chown -R runner:runner /opt/hostedtoolcache /home/runner

ENV RUNNER_USER=runner \
    RUNNER_HOME=/home/runner \
    AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache \
    RUNNER_TOOL_CACHE=/opt/hostedtoolcache \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_NOLOGO=1 \
    PATH=/home/runner/.local/bin:/opt/cargo/bin:/usr/local/go/bin:$PATH

# Cleanup
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /root/.cache \
        /root/.npm

# Image metadata at final stage
LABEL org.opencontainers.image.title="Ubuntu ${UBUNTU_VERSION} GitHub Actions Runner" \
      org.opencontainers.image.description="Production-grade Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME}) runner image with full GitHub Actions toolchain" \
      org.opencontainers.image.version="${UBUNTU_VERSION}" \
      org.opencontainers.image.base.name="ubuntu:${UBUNTU_VERSION}"

WORKDIR /home/runner
USER runner

COPY --chown=runner:runner scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
