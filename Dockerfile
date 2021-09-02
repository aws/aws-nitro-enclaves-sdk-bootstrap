FROM public.ecr.aws/ubuntu/ubuntu:18.04
ARG BUILD_ARCH=x86_64
ENV BUILD_ARCH=${BUILD_ARCH}

SHELL ["/bin/bash", "-c"]

# Install compile tools including aarch64 toolchain for cross compile
RUN apt-get update -y && apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev gnupg2 curl bc
RUN apt-get update -y && apt-get install -y gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu

RUN mkdir /build

ADD ./ /build/

WORKDIR /build

RUN gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org -vv
RUN make BUILD_ARCH=${BUILD_ARCH}

