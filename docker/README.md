# Dockerfiles for demo environments

This directory contains Dockerfiles to build CRaC JDK images based on Ubuntu and
Alpine Linux. Supported targets are `linux/amd64` and `linux/arm64`.

## Building an Ubuntu image

There are two Dockerfiles for Ubuntu images:

- When targeting CPU architecture of the host machine use
  `crac-ubuntu.Dockerfile`:
  ```shell
  docker build -t crac-ubuntu -f crac-ubuntu.Dockerfile .
  ```
- When the targeted CPU architecture differs from the host's architecture use
  `crac-ubuntu-cross.Dockerfile` to leverage cross-compilation, for example:
  ```shell
  docker build -t crac-ubuntu -f crac-ubuntu-cross.Dockerfile --platform linux/arm64 .
  ```

## Building an Alpine Linux image

Use `crac-alpine.Dockerfile` to build Alpine Linux images:

```shell
docker build -t crac-alpine -f crac-alpine.Dockerfile .
```

There is no cross-compilation provided for Alpine Linux, so to get an image for
a different CPU architecture just use the `--platform` option with the same
Dockerfile. In this case the build process will be emulated thus taking
significantly more time (probably about 10 times more).
