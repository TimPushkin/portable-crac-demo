# Create a sysroot for cross-compilation
FROM --platform=$BUILDPLATFORM ubuntu:22.04 AS sysroot
RUN apt-get update && apt-get install --no-install-recommends --yes \
    debootstrap ca-certificates qemu-user-static
ARG TARGETARCH
RUN debootstrap \
    --arch="$TARGETARCH" \
    --verbose \
    --include=fakeroot,symlinks,build-essential,libx11-dev,libxext-dev,libxrender-dev,libxrandr-dev,libxtst-dev,libxt-dev,libcups2-dev,libfontconfig1-dev,libasound2-dev,libfreetype6-dev,libpng-dev,libffi-dev \
    --resolve-deps \
    --variant=minbase \
    bookworm \
    sysroot \
    https://httpredir.debian.org/debian/
RUN chroot sysroot symlinks -cr .

# Cross-compile JDK
FROM --platform=$BUILDPLATFORM ubuntu:22.04 AS build
ARG TARGETARCH
RUN <<EOF
    case "$TARGETARCH" in
        amd64) TARGETARCH_GNU="x86-64";  TARGETARCH_JDK="x86_64";;
        arm64) TARGETARCH_GNU="aarch64"; TARGETARCH_JDK="aarch64";;
        *)     echo "Unsupported target arch: $TARGETARCH"; exit 1;;
    esac
    echo "$TARGETARCH_GNU" > targetarch-gnu
    echo "$TARGETARCH_JDK" > targetarch-jdk
EOF
RUN apt-get update && apt-get install --no-install-recommends --yes \
    autoconf make file zip unzip openjdk-21-jdk g++ "g++-$(cat targetarch-gnu)-linux-gnu" libz-dev
COPY --from=sysroot /sysroot sysroot
ADD https://github.com/TimPushkin/crac.git crac
ARG TARGETOS
RUN cd crac && \
    sh ./configure \
        --openjdk-target="$(cat /targetarch-jdk)-linux-gnu" \
        --with-sysroot="/sysroot" \
        --with-conf-name="$TARGETOS-$TARGETARCH" && \
    make jdk-image

FROM ubuntu:22.04 AS main
ENV JAVA_HOME=/jdk
ARG CR_DIR=/cr
ARG EXPOSED_PORT=8080
VOLUME $CR_DIR
EXPOSE $EXPOSED_PORT
ARG TARGETOS
ARG TARGETARCH
COPY --from=build "/crac/build/$TARGETOS-$TARGETARCH/images/jdk" /jdk
