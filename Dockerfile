FROM debian:latest
SHELL ["/bin/bash", "--login", "-c"]

# Install dev tools
RUN apt-get update && apt-get install -y \
    curl \
    fish \
    git \
    htop \
    iperf3 \
    iputils-ping \
    jq \
    mosh \
    mtr \
    openssh-server \
    rbenv \
    sudo \
    tcpdump \
    tmux \
    traceroute

# Install rbenv dependencies
RUN apt-get install -y autoconf patch build-essential rustc libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev

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
USER $USER

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Install Ruby
RUN rbenv install $(rbenv install -l | grep -v - | tail -1)

# Install Node
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$(curl -s "https://api.github.com/repos/nvm-sh/nvm/tags" | jq -r '.[0].name')/install.sh | bash
RUN source /home/$USER/.nvm/nvm.sh && nvm install --lts

# Install dotfiles
#TODO

WORKDIR /home/$USER/
COPY .env .env
COPY .git-credentials .git-credentials
COPY bootstrap /usr/local/bin/bootstrap
ARG GITHUB_USERNAME
ENTRYPOINT /usr/local/bin/bootstrap
