FROM debian:latest
SHELL ["/bin/bash", "--login", "-c"]

# Install core dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg

# Add Docker's official GPG key and repository
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install dev tools
RUN apt-get update && apt-get install -y \
    fish \
    docker-ce-cli \
    dnsutils \
    git \
    gh \
    golang \
    htop \
    iperf3 \
    iproute2 \
    iputils-ping \
    jq \
    libffi-dev \
    libpq-dev \
    libvirt-dev \
    libyaml-dev \
    locales \
    mosh \
    mtr \
    openssh-server \
    postgresql \
    rbenv \
    redis-server \
    ripgrep \
    sudo \
    tcpdump \
    tmux \
    traceroute \
    universal-ctags \
    vim \
    wget && \
    # Clean up apt cache to save space
    apt-get clean && rm -rf /var/lib/apt/lists*

# Install Stripe CLI
RUN STRIPE_ARCH=$(dpkg --print-architecture | sed 's/amd64/x86_64/') && \
    STRIPE_VERSION=$(curl -s https://api.github.com/repos/stripe/stripe-cli/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//') && \
    curl -fsSL "https://github.com/stripe/stripe-cli/releases/download/v${STRIPE_VERSION}/stripe_${STRIPE_VERSION}_linux_${STRIPE_ARCH}.tar.gz" | tar -xz -C /usr/local/bin stripe

# Generate locales
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG=en_US.utf8

# Set timezone
RUN echo "America/New_York" > /etc/timezone && \
    ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime

# Install Tailscale
COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscale /usr/local/bin/tailscale
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Set up the default user
ARG USER
RUN useradd -ms /bin/bash "$USER" && \
    echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER $USER
WORKDIR /home/$USER/

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Install Ruby
RUN git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build && \
    rbenv install $(rbenv install -l | grep -v - | tail -1) && \
    rbenv global $(rbenv install -l | grep -v - | tail -1) && \
    rbenv rehash

# Install Node
SHELL ["/bin/bash", "--login", "-c", "-i"]
RUN curl -fsSL https://fnm.vercel.app/install | bash && \
    source /home/$USER/.bashrc && \
    fnm install --lts && \
    npm install -g yarn

# Install Playwright browsers and system dependencies
RUN npx playwright install --with-deps

# Install Claude
RUN curl -fsSL https://claude.ai/install.sh | bash

SHELL ["/bin/bash", "--login", "-c"]

# Import GPG key
COPY gpg.key .
RUN mkdir -p /home/$USER/.gnupg && \
    chmod 700 /home/$USER/.gnupg && \
    gpg --batch --import gpg.key && \
    sudo rm gpg.key

# Copy secrets into container
COPY .env .
COPY .git-credentials .

# Install dotfiles
SHELL ["/bin/bash", "--login", "-c", "-i"]
RUN mkdir -p /home/$USER/dev/ && \
    cd /home/$USER/dev/ && \
    git clone https://github.com/bswinnerton/dotfiles.git && \
    ln -s /home/$USER/dev/dotfiles /home/$USER/.dotfiles && \
    cd /home/$USER/dev/dotfiles && \
    ./install && \
    vim +'PlugInstall --sync' +qa
SHELL ["/bin/bash", "--login", "-c"]

# Configure gpg-agent (after dotfiles install which may overwrite .gnupg config)
RUN echo "default-cache-ttl 31536000" > /home/$USER/.gnupg/gpg-agent.conf && \
    echo "max-cache-ttl 31536000" >> /home/$USER/.gnupg/gpg-agent.conf && \
    echo "allow-preset-passphrase" >> /home/$USER/.gnupg/gpg-agent.conf

# Configure Git
RUN git config --global user.signingkey $(gpg --homedir /home/$USER/.gnupg --list-secret-keys --keyid-format LONG | grep 'sec' | awk '{print $2}' | cut -d'/' -f2) && \
    git config --global commit.gpgSign true && \
    git config --global credential.helper 'store --file /home/$USER/.git-credentials'

# Clone commonly used repositories
RUN mkdir -p /home/$USER/dev/neptune-networks && \
    cd /home/$USER/dev/ && \
    git clone https://github.com/bswinnerton/dev.git && \
    cd /home/$USER/dev/neptune-networks/ && \
    git clone https://github.com/neptune-networks/containers.git && \
    git clone https://github.com/neptune-networks/infrastructure.git && \
    git clone https://github.com/neptune-networks/ipguide.git && \
    git clone https://github.com/neptune-networks/neptune.git && \
    git clone https://github.com/neptune-networks/network.git

# Install overmind
RUN eval "$(rbenv init -)" && \
    gem install overmind

# Call the bootstrap script at runtime
WORKDIR /home/$USER/
RUN sudo chsh -s /bin/fish $USER
COPY bootstrap /usr/local/bin/bootstrap
ENTRYPOINT /usr/local/bin/bootstrap
