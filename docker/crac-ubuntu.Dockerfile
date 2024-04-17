FROM ubuntu:22.04 AS build
RUN apt-get update && apt-get install --no-install-recommends --yes \
    autoconf make file zip unzip openjdk-21-jdk g++ \
    libasound2-dev libcups2-dev libfontconfig1-dev libx11-dev libxext-dev libxrender-dev libxrandr-dev libxtst-dev libxt-dev
ADD https://github.com/TimPushkin/crac.git crac
ARG TARGETOS
ARG TARGETARCH
RUN cd crac && \
    sh ./configure --with-conf-name="$TARGETOS-$TARGETARCH" && \
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
