#
# Start with a well-known base image
FROM debian:latest

WORKDIR /tmp
USER root

# The parent image uses dash shell by default, while some of the software we install expect bash. The main difference
# relevant for building this dockerfile is that dash does not offer the 'source' built-in.
SHELL ["/bin/bash", "-c"]


#
# Install software needed for development, compilation and the general interactive use of this container.
# To save on cache layers, we'll use this opportunity to install tooling for C++ & Node - at the time of writing this
# GCC 12.2, CLang 16 and Node 18.19 are the latest versions.
#
# NOTE: Don't use the 'RUN <<END' syntax as it doesn't stop when one of the commands fails.
RUN apt update  && \
    apt install -y  ssh  gpg  git  tmux  procps  curl  wget  zip  unzip  vim  nano  \
                    build-essential  autoconf  make  cmake  gcc  g++  libtool  gdb  clang-tools-16  ccache  valgrind  \
                    python3  \
                    nodejs  npm  && \
    apt clean


#
# Create user account for the normal use of this image
RUN useradd  --uid 1000  --create-home  --shell /bin/bash  builder


#
# Execute the rest of the steps from the runtime user's account
USER builder


#
# Install Java toolchain using https://sdkman.io
# Note that we're installing Temurin distribution of JDK: https://adoptium.net/temurin/releases/
#
# SDKMan's CDN can get overloaded every now and then, so we'll strategically use multiple cache layers to make it
# less frustrating to resume the local docker builds.
RUN curl --proto '=https' --tlsv1.2 -sSf "https://get.sdkman.io?rcupdate=false" |  \
    bash

RUN source /home/builder/.sdkman/bin/sdkman-init.sh  && \
    sdk install java 21.0.4-tem  && \
    sdk flush tmp

RUN source /home/builder/.sdkman/bin/sdkman-init.sh  && \
    sdk install maven 3.9.9  && \
    sdk flush tmp

RUN source /home/builder/.sdkman/bin/sdkman-init.sh  && \
    sdk flush all  && \
    sdk offline enable

ENV JAVA_HOME="/home/builder/.sdkman/candidates/java/current/"
ENV PATH="/home/builder/.sdkman/candidates/java/current/bin:/home/builder/.sdkman/candidates/maven/current/bin/:$PATH"


#
# Install Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" |  \
    bash -s --   --default-toolchain stable  --no-modify-path  -y

ENV PATH="/home/builder/.cargo/bin:$PATH"


#
# Install Go toolchain
RUN mkdir -p  /home/builder/.golang  && \
    curl --proto '=https' --tlsv1.2 -sSf "https://dl.google.com/go/go1.23.1.linux-amd64.tar.gz" -o /tmp/golang.tar.gz  && \
    tar -xvzf  /tmp/golang.tar.gz  --strip-components 1  -C  /home/builder/.golang/  && \
    rm  /tmp/golang.tar.gz

ENV PATH="/home/builder/.golang/bin:$PATH"


#
# Finish up
USER builder
WORKDIR /home/builder

CMD ["/bin/bash"]

# eof
