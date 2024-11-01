# Docker-based development environment

## To run

```
docker run -it --rm bswinnerton/dev:latest
```

## To build locally

1. Populate `.env` and `.git-credentials` files
2. Build Docker container:
  ```
  docker build -t bswinnerton/dev:latest --build-arg GITHUB_USERNAME=bswinnerton --build-arg USER=brooks .
  ```
