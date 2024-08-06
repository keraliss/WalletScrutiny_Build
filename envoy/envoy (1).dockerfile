# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04
# Set environment variables
ENV TZ=America/New_York
ARG DEBIAN_FRONTEND=noninteractive
# Install necessary packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
postgresql \
curl \
build-essential \
libssl-dev \
pkg-config \
libpq-dev \
git \
unzip \
xz-utils \
zip \
libglu1-mesa \
openjdk-8-jdk \
openjdk-17-jdk \
wget \
python2 \
autoconf \
clang \
cmake \
ninja-build \
libgtk-3-0 \
libgtk-3-dev \
v4l2loopback-dkms \
v4l2loopback-utils \
libzbar-dev \
libzbar0 \
libzbargtk-dev \
libjsoncpp-dev \
libsecret-1-dev \
libsecret-1-0 \
ffmpeg \
xvfb \
xdotool \
x11-utils \
libstdc++-12-dev \
llvm-14 \
libsdl2-dev \
libclang1-14 \
libtool \
sudo \
libusb-1.0-0-dev \
python3-virtualenv \
xorg \
xdg-user-dirs \
xterm \
tesseract-ocr \
&& apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# Install Android SDK Command-line Tools
RUN update-java-alternatives --set /usr/lib/jvm/java-1.8.0-openjdk-amd64
RUN mkdir -p /root/Android/sdk
ENV ANDROID_SDK_ROOT /root/Android/sdk
RUN mkdir -p /root/.android && touch /root/.android/repositories.cfg && \
wget -O sdk-tools.zip https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip && \
unzip sdk-tools.zip -d /root/Android/sdk && rm sdk-tools.zip
# Install required Android components
RUN cd /root/Android/sdk/tools/bin && yes | ./sdkmanager --licenses && \
./sdkmanager "build-tools;30.0.2" "platform-tools" "cmdline-tools;latest" "ndk;25.2.9519653"
ENV PATH "$PATH:/root/Android/sdk/platform-tools:/root/Android/sdk/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin"
# Install Flutter SDK
RUN git clone https://github.com/flutter/flutter.git /root/flutter
ENV PATH "$PATH:/root/flutter/bin"
RUN flutter channel stable && \
flutter upgrade && \
flutter config --enable-linux-desktop
# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable -y
ENV PATH=/root/.cargo/bin:$PATH
# Install additional dependencies for Rust and Android builds
RUN apt-get update && apt-get install -y \
clang \
lld \
libclang-dev \
&& apt-get clean
# Clone the repository and set working directory
RUN git clone https://github.com/Foundation-Devices/envoy.git /root/repo
WORKDIR /root/repo
# Make the build script executable and run it
RUN chmod +x build_ffi_android.sh && ./build_ffi_android.sh

# Create a new script to run the build and keep the container running
RUN echo '#!/bin/bash' > /root/build_and_keep_running.sh && \
    echo 'cd /root/repo && ./build_ffi_android.sh' >> /root/build_and_keep_running.sh && \
    echo 'tail -f /dev/null' >> /root/build_and_keep_running.sh && \
    chmod +x /root/build_and_keep_running.sh

# Set the new script as the CMD
CMD ["/root/build_and_keep_running.sh"]