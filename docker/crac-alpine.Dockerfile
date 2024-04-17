FROM alpine:3.19 AS build
RUN apk add --no-cache \
    bash autoconf make file zip unzip openjdk21-jdk g++ \
    alsa-lib-dev cups-dev fontconfig-dev libxtst-dev libxt-dev libxrender-dev libxrandr-dev
ADD https://github.com/TimPushkin/crac.git crac
ARG TARGETOS
ARG TARGETARCH
RUN cd crac && \
    sh ./configure --with-conf-name="$TARGETOS-$TARGETARCH" \
        # Workaround of JDK-8324153
        --with-extra-cflags=-D_LARGEFILE64_SOURCE --with-extra-cxxflags=-D_LARGEFILE64_SOURCE && \
    make jdk-image

FROM alpine:3.19 AS main
ENV JAVA_HOME=/jdk
ARG CR_DIR=/cr
ARG EXPOSED_PORT=8080
VOLUME $CR_DIR
EXPOSE $EXPOSED_PORT
ARG TARGETOS
ARG TARGETARCH
COPY --from=build "/crac/build/$TARGETOS-$TARGETARCH/images/jdk" /jdk
