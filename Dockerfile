FROM debian:latest
SHELL ["/bin/bash", "--login", "-c"]

# Install dev tools
RUN apt-get update && apt-get install -y \
    curl \
    fish \
    dnsutils \
    git \
    htop \
    iperf3 \
    iproute2 \
    iputils-ping \
    jq \
    locales \
    mosh \
    mtr \
    openssh-server \
    rbenv \
    ripgrep \
    ruby-build \
    sudo \
    tcpdump \
    tmux \
    traceroute \
    universal-ctags \
    vim \
    wget && \
    # Clean up apt cache to save space
    apt-get clean && rm -rf /var/lib/apt/lists*

# Generate locales
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG=en_US.utf8

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
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal

# Install Ruby
RUN rbenv install $(rbenv install -l | grep -v - | tail -1) && \
    rbenv global $(rbenv install -l | grep -v - | tail -1)

# Install Node
SHELL ["/bin/bash", "--login", "-c", "-i"]
RUN curl -fsSL https://fnm.vercel.app/install | bash && \
    source /home/$USER/.bashrc && \
    fnm install --lts && \
    npm install -g yarn
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
    git clone https://github.com/neptune-networks/neptune-networks.git && \
    git clone https://github.com/neptune-networks/network.git

# Call the bootstrap script at runtime
WORKDIR /home/$USER/
RUN sudo chsh -s /bin/fish $USER
COPY bootstrap /usr/local/bin/bootstrap
ENTRYPOINT /usr/local/bin/bootstrap
