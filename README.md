# Demos for portable CRaC mode

Demonstrates how the experimental portable mode of CRaC can be used to transfer
the state of a running JVM app between machines with different OSes and CPU
architectures.

The repository contains several example applications and two containerized
environments to transfer the apps between:

- Source: Ubuntu 22.04 on AArch64
- Target: Alpine Linux 3.19 on x86-64

*Source* is intended for checkpointing while *target* is for restoring, though
everything should also work when used the other way around.

## Requirements

- x86-64 CPU
    - Currently the source environment (AArch64) is emulated while the target
      one (x86-64) is run directly on the hardware
    - The CPU should be powerful enough to run AArch64 emulation, for reference,
      AMD Ryzen 5 5600X delivered a pleasant experience during the development
- Docker
- JDK and Maven (to build the example apps, CRaC JDK is not required)

## How to run

When cloning make sure to use `--recurse-submodules` to include the submodules,
then follow the steps below to run the demo. Steps 2-4 are given for
`example-jetty` but should be similar for the rest of the example apps

1. Build Docker images for the source and target environments, this should take
   about 20 minutes in total:
   ```shell
   docker build -t demo-source -f docker/source.Dockerfile .
   docker build -t demo-target -f docker/target.Dockerfile .
   ```
2. Compile the example app you plan to run:
   ```shell
   cd apps/example-jetty
   mvn package
   ```
3. Checkpoint:
    1. Start the source container:
       ```shell
       docker run -it \
         --mount "src=$PWD/apps/example-jetty,dst=/app,type=bind" \
         -p 8080:8080 \
         demo-source
       ```
        - Mounted `src` should point wherever the app is and `dst` must
          be `/app`
        - The port is forwarded to be able to access the Jetty server from the
          host machine (other example apps do not need this), the source can be
          an arbitrary port and the target must be `8080`
    2. Wait for the emulator to boot (should take 1-2 minutes), then sign in
       with login `ubuntu` and password `1234`.
        - Before trying to sign in wait for
          `[  OK  ] Reached target Cloud-init target.` message to appear: it
          will probably happen some time after the login screen appears — if the
          credentials are invalid you most likely just have not waited enough
        - Inside the emulator TTY may be acting weird, you can optionally fix
          this by calling `stty cols $COLS rows $ROWS` and specifying the number
          of columns and rows in your terminal
    3. Launch the app using CRaC JDK in `$JAVA_HOME` and checkpoint it to `/cr`:
       ```shell
       $JAVA_HOME/bin/java -XX:CREngine="" -XX:CRaCCheckpointTo=/cr \
         -Djdk.crac.resource-policies=/app/res-policies.yaml \
         -jar /app/target/example-jetty-1.0-SNAPSHOT.jar
       ```
        - `/cr` is a volume configured to be shared between the containers
        - The Jetty server can be accessed at `localhost:8080`, sending a
          request to `localhost:8080/checkpoint` will make it checkpoint
    4. To stop the container press `Ctrl-A` followed by `X`.
4. Restore:
    1. Start the target container:
       ```shell
       docker run -it \
         --volumes-from "$(docker ps -ql)" \
         --mount "src=$PWD/apps/example-jetty,dst=/app,type=bind" \
         -p 8080:8080 \
         demo-target
       ```
        - `--volumes-from` makes `/cr` from the source available to the target
        - Same rules apply to the mount and port here as with the source
          container
    2. Restore the checkpointed app using CRaC JDK in `$JAVA_HOME`:
       ```shell
       $JAVA_HOME/bin/java -XX:CREngine="" -XX:CRaCRestoreFrom=/cr \
         -Djdk.crac.resource-policies=/app/res-policies.yaml \
         -jar /app/target/example-jetty-1.0-SNAPSHOT.jar
       ```
        - The restored Jetty server should again be accessible
          at `localhost:8080`
    3. To stop the container press `Ctrl-C` and then type `exit`.
