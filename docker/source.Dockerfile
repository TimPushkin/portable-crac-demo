# Image for the source environment emulation (i.e. the one to use for checkpointing)


# Create a sysroot for cross-compilation
FROM --platform=linux/amd64 ubuntu:22.04 AS sysroot

RUN apt-get update && apt-get install --no-install-recommends --yes \
    debootstrap ca-certificates qemu-user-static

RUN debootstrap \
    --arch=arm64 \
    --verbose \
    --include=fakeroot,symlinks,build-essential,libx11-dev,libxext-dev,libxrender-dev,libxrandr-dev,libxtst-dev,libxt-dev,libcups2-dev,libfontconfig1-dev,libasound2-dev,libfreetype6-dev,libpng-dev,libffi-dev \
    --resolve-deps \
    --variant=minbase \
    bookworm \
    sysroot-arm64 \
    https://httpredir.debian.org/debian/
RUN chroot sysroot-arm64 symlinks -cr .


# Cross-compile CRaC JDK for the guest platform
FROM --platform=linux/amd64 ubuntu:22.04 AS build

RUN apt-get update && apt-get install --no-install-recommends --yes \
    autoconf make file zip unzip openjdk-21-jdk g++ g++-aarch64-linux-gnu libz-dev

COPY --from=sysroot /sysroot-arm64 /sysroot-arm64

ADD https://github.com/TimPushkin/crac.git crac
RUN cd crac && \
    sh ./configure --openjdk-target=aarch64-linux-gnu --with-sysroot="/sysroot-arm64" && \
    make jdk-image


# Prepare for emulation
FROM --platform=linux/amd64 ubuntu:22.04 AS main

EXPOSE 8080

RUN mkdir /cr && adduser ubuntu && chown ubuntu /cr
VOLUME /cr

WORKDIR /emu

RUN apt-get update && apt-get install --no-install-recommends --yes \
    qemu-system-arm qemu-efi-aarch64 ipxe-qemu cloud-image-utils

RUN cp /usr/share/AAVMF/AAVMF_VARS.fd .

ADD https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-arm64.img ubuntu.img
RUN qemu-img resize ubuntu.img +10G

RUN printf \
'#cloud-config\n\
password: "1234"\n\
chpasswd: { expire: False }\n\
bootcmd:\n\
  - "mkdir -p /jdk /app /cr"\n\
  - "mount -t 9p -o trans=virtio,version=9p2000.L,msize=104857600 jdk /jdk"\n\
  - "mount -t 9p -o trans=virtio,version=9p2000.L,msize=104857600 app /app"\n\
  - "mount -t 9p -o trans=virtio,version=9p2000.L,msize=104857600 cr /cr"\n\
write_files:\n\
  - path: /etc/environment\n\
    content: |\n\
      JAVA_HOME=/jdk\n\
    append: true\n\
' > user-data.yaml && \
    cloud-localds cloud-init-data.img user-data.yaml && \
    rm user-data.yaml

COPY --from=build /crac/build/linux-aarch64-server-release/images/jdk /jdk

ENTRYPOINT qemu-system-aarch64 \
    # General machine configuration
    -M virt \
    -cpu max,pauth-impdef=on \
    -smp cores=4,threads=2 \
    -m 4G \
    # UEFI
    -drive if=pflash,file=/usr/share/AAVMF/AAVMF_CODE.fd,format=raw,media=cdrom,read-only=on \
    -drive if=pflash,file=AAVMF_VARS.fd,format=raw \
    # Cloud image
    -drive if=virtio,file=ubuntu.img \
    -drive if=virtio,file=cloud-init-data.img,format=raw,media=cdrom,read-only=on \
    # Other
    -virtfs local,path=/jdk,mount_tag=jdk,security_model=none \
    -virtfs local,path=/app,mount_tag=app,security_model=none \
    -virtfs local,path=/cr,mount_tag=cr,security_model=none \
    -nic user,model=virtio,hostfwd=tcp::8080-:8080 \
    -nographic

