# Image of the target environment (i.e. the one to use for restoring)

FROM --platform=linux/amd64 alpine:3.19 AS build
RUN apk add --no-cache \
    bash autoconf make file zip unzip openjdk21-jdk g++ \
    alsa-lib-dev cups-dev fontconfig-dev libxtst-dev libxt-dev libxrender-dev libxrandr-dev
ADD https://github.com/TimPushkin/crac.git crac
RUN cd crac && \
    # The extra flags are a workaround of JDK-8324153
    sh ./configure --with-extra-cflags=-D_LARGEFILE64_SOURCE --with-extra-cxxflags=-D_LARGEFILE64_SOURCE && \
    make jdk-image

FROM --platform=linux/amd64 alpine:3.19 AS main
VOLUME /cr
EXPOSE 8080
ENV JAVA_HOME=/jdk
COPY --from=build /crac/build/linux-x86_64-server-release/images/jdk $JAVA_HOME

