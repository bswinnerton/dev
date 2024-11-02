FROM debian:latest
SHELL ["/bin/bash", "--login", "-c"]

# Install dev tools
RUN apt-get update && apt-get install -y \
    curl \
    fish \
    dnsutils \
    git \
    golang \
    htop \
    iperf3 \
    iputils-ping \
    jq \
    locales \
    mosh \
    mtr \
    openssh-server \
    rbenv \
    ripgrep \
    sudo \
    tcpdump \
    tmux \
    traceroute \
    universal-ctags \
    vim

# Install rbenv dependencies
RUN apt-get install -y autoconf patch build-essential rustc libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev

# Generate locales
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen

# Install Tailscale
COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscale /usr/local/bin/tailscale
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Set up the default user
ARG USER
ENV USER=$USER
RUN useradd -ms /bin/bash "$USER"

# Allow sudo access
RUN echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Continue as the default user
RUN chsh -s /bin/fish $USER
USER $USER
WORKDIR /home/$USER/

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Install Ruby
RUN rbenv install $(rbenv install -l | grep -v - | tail -1)
RUN rbenv global $(rbenv install -l | grep -v - | tail -1)

# Install Node
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$(curl -s "https://api.github.com/repos/nvm-sh/nvm/tags" | jq -r '.[0].name')/install.sh | bash
RUN source /home/$USER/.nvm/nvm.sh && nvm install --lts

# Copy files to ~/
COPY .env .
COPY .git-credentials .

# Import authorized SSH keys
RUN mkdir /home/$USER/.ssh
RUN curl -s https://github.com/$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user | jq -r .login).keys > /home/$USER/.ssh/authorized_keys

# Import GPG key
COPY gpg.key .
RUN mkdir -p /home/$USER/.gnupg
RUN chmod 700 /home/$USER/.gnupg
RUN gpg --batch --import gpg.key
RUN rm gpg.key

# Install dotfiles
RUN mkdir -p /home/$USER/dev/
WORKDIR /home/$USER/dev/
RUN git clone https://github.com/bswinnerton/dotfiles.git
RUN ln -s /home/$USER/dev/dotfiles /home/$USER/.dotfiles
WORKDIR /home/$USER/dev/dotfiles
RUN ./install
RUN vim +'PlugInstall --sync' +qa

# Configure Git
RUN git config --global user.signingkey $(gpg --homedir /home/$USER/.gnupg --list-secret-keys --keyid-format LONG | grep 'sec' | awk '{print $2}' | cut -d'/' -f2)
RUN git config --global commit.gpgSign true
RUN git config --global credential.helper 'store --file /home/$USER/.git-credentials'

# Clone commonly used repositories
RUN mkdir -p /home/$USER/dev/neptune-networks/
WORKDIR /home/$USER/dev/neptune-networks/
RUN git clone https://github.com/bswinnerton/dev.git
RUN git clone https://github.com/neptune-networks/containers.git
RUN git clone https://github.com/neptune-networks/infrastructure.git
RUN git clone https://github.com/neptune-networks/ipguide.git
RUN git clone https://github.com/neptune-networks/neptune-networks.git
RUN git clone https://github.com/neptune-networks/network.git

# Call the bootstrap script at runtime
WORKDIR /home/$USER/
COPY bootstrap /usr/local/bin/bootstrap
ENTRYPOINT /usr/local/bin/bootstrap
