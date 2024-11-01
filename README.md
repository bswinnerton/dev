# Docker-based development environment

```
docker run -it --rm bswinnerton/dev:latest
```

## Forking

If you want to make a copy of this, you'll need to set a few secrets and repository variables in GitHub Actions:

### Repository secrets

- `CONTAINER_GITHUB_TOKEN`: A GitHub personal access token so that repositories can be cloned
- `CONTAINER_TAILSCALE_KEY`: A Tailscale auth key so that the container can connect to your tailnet
- `DOCKER_PASSWORD`: The password for your private Docker registry

### Repository variables

- `CONTAINER_USER`: The name of the user you would like inside the container
- `DOCKER_REGISTRY`: The URL of your private Docker registry (without a suffix like `https://`)
- `DOCKER_USERNAME`: The username for your private Docker registry

## To build locally

1. Populate `.env` and `.git-credentials` files
2. Build Docker container:
  ```
  docker build -t bswinnerton/dev:latest --build-arg GITHUB_USERNAME=bswinnerton --build-arg USER=brooks .
  ```
