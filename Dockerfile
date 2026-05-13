# Default to the latest LTS if not specified
ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION}

# Replicate GitHub Runner Environment Variables
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_USER=runner
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
ENV ImageOS=ubuntu${UBUNTU_VERSION}

# Create the standard runner user and tool cache directory
# This makes it natively compatible with actions/setup-node, setup-python, etc.
RUN useradd -m -s /bin/bash ${RUNNER_USER} \
    && mkdir -p ${RUNNER_TOOL_CACHE} \
    && chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_TOOL_CACHE}

# 1. Install GitHub's exact base package list
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    zip \
    unzip \
    tar \
    gzip \
    zstd \
    lz4 \
    rsync \
    software-properties-common \
    gnupg \
    sudo \
    build-essential \
    # Networking and system tools \
    net-tools \
    iputils-ping \
    dnsutils \
    time \
    locales \
    tzdata \
    # Core Languages
    python3 \
    python3-pip \
    python3-venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Allow passwordless sudo for the runner user (Exactly like GitHub VMs)
RUN echo "${RUNNER_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. Install Docker CLI (Allows Docker-in-Docker triggers if socket is mounted)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
       $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 4. Install Cloud CLIs (AWS, Azure - Standard on GitHub Runners)
RUN curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip \
    && unzip awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# 5. Set Locale to match GitHub officially
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Switch to the runner user to replicate the exact runtime environment
USER ${RUNNER_USER}
WORKDIR /home/${RUNNER_USER}

CMD ["/bin/bash"]
