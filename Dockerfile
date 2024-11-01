# TODO:
# - [x] Create ephemeral (but named?) Tailscale key
# - Add secrets in GitHub for:
#   - [x] Tailscale key
#   - [x] Neptune's Docker registry
#   - [x] GitHub to pull repos
# - [ ] Create a dev.brooks.network CNAME to the running Tailscale docker container

ARG USERNAME

FROM debian:latest
SHELL ["/bin/bash", "--login", "-c"]

# Install dev tools
RUN apt-get update && apt-get install -y \
    curl \
    fish \
    git \
    htop \
    iperf3 \
    jq \
    mosh \
    openssh-server \
    rbenv \
    tcpdump \
    tmux

# Install rbenv dependencies
RUN apt-get install -y autoconf patch build-essential rustc libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev

# Set up default user
RUN useradd -ms /bin/bash $USERNAME
USER $USERNAME

# Pull SSH keys from GitHub
RUN curl -s https://github.com/$GITHUB_ACTOR.keys > ~/.ssh/authorized_keys

# Store GitHub credentials
RUN git config --global credential.helper 'store --file ~/.git-credentials'
RUN echo "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com" > ~/.git-credentials

# Install & Configure Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh
CMD tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 & && \
    tailscale login --auth-key $TAILSCALE_KEY && \
    tailscale up --accept-routes --ssh --hostname=dev

# Install Ruby
RUN rbenv install $(rbenv install -l | grep -v - | tail -1)

# Install Node
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$(curl -s "https://api.github.com/repos/nvm-sh/nvm/tags" | jq -r '.[0].name')/install.sh | bash
RUN source ~/.nvm/nvm.sh
RUN nvm install --lts

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Install dotfiles
#TODO

# Clone repositories
WORKDIR /home/$USERNAME/dev/
#RUN git clone https://github.com/bswinnerton/dev.git
#RUN git clone https://github.com/bswinnerton/dotfiles.git
#RUN git clone https://github.com/neptune-networks/containers.git
#RUN git clone https://github.com/neptune-networks/infrastructure.git
#RUN git clone https://github.com/neptune-networks/ipguide.git
#RUN git clone https://github.com/neptune-networks/neptune-networks.git
#RUN git clone https://github.com/neptune-networks/network.git

# Change shell to fish
RUN usermod -s /bin/fish $USERNAME
