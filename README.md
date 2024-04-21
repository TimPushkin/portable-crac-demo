# Demos for portable CRaC mode

Demonstrates how the experimental portable mode of CRaC can be used to transfer
the state of a running JVM app between machines with different OSes and CPU
architectures: the repository contains several example applications and
containerized environments to run them.

When cloning make sure to use `--recurse-submodules` to include the submodules.

## Prerequisites

You will need the following on your host system:

- [Docker](https://docs.docker.com/get-docker/) — to use the containerized
  environments
    - CPU emulation must be supported: recent Docker Desktop versions should
      include it by default but if you use just Docker Engine you will probably
      need to also install [QEMU](https://www.qemu.org/download/) (user mode
      emulation is sufficient)
    - You can test the emulation support by executing
      `docker run --platform linux/$ARCH hello-world` with `$ARCH` different
      from the host architecture (e.g. `arm64` if the host is x86 and `amd64` if
      it is ARM): if it succeeds then you are good to go but if you get
      `exec format error` then you need to configure your Docker
- [JDK 14+](https://www.java.com/en/download/help/download_options.html) and
  [Maven](https://maven.apache.org/download.cgi) — to build the example apps
    - The JDK does not have to be a CRaC JDK

## How to run

In this example we will checkpoint `example-jetty` in `Ubuntu/arm64` and restore
it in `Alpine Linux/amd64`. The process should be similar for other apps and
platforms.

1. Download Docker images from
   [GitHub releases](https://github.com/TimPushkin/portable-crac-demo/releases)
   and load them by executing these commands:
   ```shell
   docker load --input crac-ubuntu-arm64.tar.gz
   docker load --input crac-alpine-amd64.tar.gz
   ```
    - To try different CPU architectures build the images manually following the
      instructions in [`docker/README.md`](docker/README.md) — the build process
      is very simple but may take tens of minutes
2. Compile the example app. In the repository's root execute:
   ```shell
   cd apps/example-jetty
   mvn package
   ```
3. Checkpoint:
    1. Start the first container. In the repository's root execute:
       ```shell
       docker run -it \
         --platform linux/arm64 \
         --mount "src=$PWD/apps/example-jetty,dst=/app,type=bind" \
         -p 8080:8080 \
         crac-ubuntu-arm64
       ```
        - Inside the container our app will be available at `/app`
        - We will need TCP port `8080` to access the Jetty server on the host
    2. Inside the container, launch the app using CRaC JDK in `$JAVA_HOME` and
       checkpoint it to `/cr`:
       ```shell
       $JAVA_HOME/bin/java -XX:CREngine="" -XX:CRaCCheckpointTo=/cr \
         -Djdk.crac.resource-policies=/app/res-policies.yaml \
         -Dport=8080 \
         -jar /app/target/example-jetty-1.0-SNAPSHOT.jar
       ```
        - `/cr` is a volume configured to be shared between the containers
        - First query the Jetty server at `localhost:8080` to warm it up and
          then make it checkpoint by sending a request to
          `localhost:8080/checkpoint`
        - The server will continue running, stop it when you wish
4. Restore:
    1. Start the second container. In the repository's root execute:
       ```shell
       docker run -it \
         --platform linux/amd64 \
         --volumes-from "$(docker ps -ql)" \
         --mount "src=$PWD/apps/example-jetty,dst=/app,type=bind" \
         -p 8081:8081 \
         crac-alpine-amd64
       ```
        - `--volumes-from` makes `/cr` from the first container available
          inside this new container
        - For a change, we will use port `8081` this time
    2. Inside the container, restore the checkpointed app using CRaC JDK in
       `$JAVA_HOME`:
       ```shell
       $JAVA_HOME/bin/java -XX:CREngine="" -XX:CRaCRestoreFrom=/cr \
         -Djdk.crac.resource-policies=/app/res-policies.yaml \
         -Dport=8081 \
         -jar /app/target/example-jetty-1.0-SNAPSHOT.jar
       ```
        - The restored Jetty server should become accessible at `localhost:8081`
