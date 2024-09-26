#
# Start with a well-known base image
FROM debian:latest

WORKDIR /tmp
USER root


#
# Install software needed for development, compilation and the general interactive use of this container.
# To save on cache layers, we'll use this opportunity to install tooling for C++ & Node - at the time of writing this
# GCC 12.2, CLang 16 and Node 18.19 are the latest versions.
#
# NOTE: Don't use the 'RUN <<END' syntax as it doesn't stop when one of the commands fails.
RUN apt update  && \
    apt install -y  ssh  gpg  git  tmux  procps  curl  wget  zip  unzip  vim  nano  \
                    build-essential  autoconf  make  cmake  gcc  g++  libtool  gdb  clang-tools-16  ccache  valgrind  \
                    python3  && \
    apt clean


#
# Create user account for the normal use of this image
RUN useradd  --uid 1000  --create-home  --shell /bin/bash  builder


#
# Execute the rest of the steps from the runtime user's account
USER builder


#
# Install Java toolchain using https://sdkman.io
# More specifically, we're installing the Temurin OpenJDK distribution: https://adoptium.net/temurin/releases/
#
# SDKMan's CDN can get overloaded every now and then, so we'll strategically use multiple cache layers to make it
# less frustrating to resume the local docker builds.
#
# NOTE: The parent image defaults to the 'dash' shell, which does not support the 'source' built-in. In addition, the
# 'SHELL' Dockerfile directive is not available under Podman, so we have to work around that too.
RUN curl --proto '=https' --tlsv1.2 -sSf "https://get.sdkman.io?rcupdate=false" | bash

RUN bash -c "source /home/builder/.sdkman/bin/sdkman-init.sh  &&  sdk install java 21.0.4-tem  &&  sdk flush tmp"

RUN bash -c "source /home/builder/.sdkman/bin/sdkman-init.sh  &&  sdk install maven 3.9.9  &&  sdk flush tmp"

RUN bash -c "source /home/builder/.sdkman/bin/sdkman-init.sh  &&  sdk flush all  &&  sdk offline enable"

#
# Install NodeJS toolchain using https://github.com/nvm-sh/nvm
# The main argument for using this tool is giving the developer the ability to switch between different versions of
# Node, depending on particular project.
# Note that in order to work around issues with cache layers we have to delay the 'ENV' directives until the very end
# of the build.
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
RUN bash -c "export NVM_DIR='$HOME/.nvm'  &&  source /home/builder/.nvm/nvm.sh  &&  nvm install 20 --default --save && nvm cache clear"


#
# Install Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | bash -s --  --default-toolchain stable  -y


#
# Install Go toolchain
RUN mkdir -p  /home/builder/.golang  && \
    curl --proto '=https' --tlsv1.2 -sSf "https://dl.google.com/go/go1.23.1.linux-amd64.tar.gz" -o /tmp/golang.tar.gz  && \
    tar -xzf  /tmp/golang.tar.gz  --strip-components 1  -C  /home/builder/.golang/  && \
    rm  /tmp/golang.tar.gz



#
# Switch to the default user and their home directory as the default working directory
USER builder
WORKDIR /home/builder


#
# Update the environment variables and save the end result to .bashrc, so that sub-shells (e.g. those started by
# tmux) would use these values as well.
#
# Also, when the image is rebuilt, the build process under Docker will start from the first ENV directive, no matter
# if further cache layers could be reused or not.
ENV NVM_DIR="/home/builder/.nvm"
ENV JAVA_HOME="/home/builder/.sdkman/candidates/java/current/"
ENV PATH="/home/builder/.golang/bin:/home/builder/.cargo/bin:/home/builder/.sdkman/candidates/maven/current/bin/:${JAVA_HOME}/bin:$PATH"

RUN echo "export NVM_DIR=\"${NVM_DIR}\"" >> /home/builder/.bashrc  && \
    echo "export JAVA_HOME=\"${JAVA_HOME}\"" >> /home/builder/.bashrc  && \
    echo "export PATH=\"${PATH}\"" >> /home/builder/.bashrc  && \
    echo "source /home/builder/.sdkman/bin/sdkman-init.sh" >> /home/builder/.bashrc  && \
    echo "nvm use default --silent" >> /home/builder/.bashrc

CMD ["/bin/bash"]

# eof
