# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables
ENV TZ=America/New_York
ENV ANDROID_SDK_ROOT=/root/Android/sdk
ENV PATH="$PATH:/root/Android/sdk/platform-tools:/root/Android/sdk/ndk/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin:/root/flutter/bin:/root/.cargo/bin"
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    postgresql curl build-essential libssl-dev pkg-config libpq-dev git unzip xz-utils zip \
    libglu1-mesa openjdk-8-jdk openjdk-17-jdk wget python2 autoconf clang cmake ninja-build \
    libgtk-3-0 libgtk-3-dev v4l2loopback-dkms v4l2loopback-utils libzbar-dev libzbar0 \
    libzbargtk-dev libjsoncpp-dev libsecret-1-dev libsecret-1-0 ffmpeg xvfb xdotool x11-utils \
    libstdc++-12-dev llvm-14 libsdl2-dev libclang1-14 libtool sudo libusb-1.0-0-dev \
    python3-virtualenv xorg xdg-user-dirs xterm tesseract-ocr ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Android SDK Command-line Tools
RUN update-java-alternatives --set /usr/lib/jvm/java-1.8.0-openjdk-amd64 && \
    mkdir -p /root/Android/sdk /root/.android && \
    touch /root/.android/repositories.cfg && \
    wget -O sdk-tools.zip https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip && \
    unzip sdk-tools.zip -d /root/Android/sdk && rm sdk-tools.zip

# Install required Android components
RUN yes | /root/Android/sdk/tools/bin/sdkmanager --licenses && \
    /root/Android/sdk/tools/bin/sdkmanager "build-tools;30.0.3" "platforms;android-30" \
    "platform-tools" "cmdline-tools;latest" "ndk;25.2.9519653"

# Install Flutter SDK
RUN git clone https://github.com/flutter/flutter.git /root/flutter && \
    flutter channel stable && \
    flutter upgrade && \
    flutter config --enable-linux-desktop && \
    flutter precache && \
    flutter doctor

# Install Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain 1.69.0 -y && \
    rustup target add aarch64-linux-android

# Clone the repository and set working directory
RUN git clone https://github.com/Foundation-Devices/envoy.git /root/repo
WORKDIR /root/repo

# Copy the build script
COPY build_ffi_android.sh /root/repo/
RUN chmod +x /root/repo/build_ffi_android.sh

# Create a new script to run the build and keep the contafiner running
RUN echo '#!/bin/bash' > /root/build_and_keep_running.sh && \
    echo 'cd /root/repo && ./build_ffi_android.sh' >> /root/build_and_keep_running.sh && \
    echo 'tail -f /dev/null' >> /root/build_and_keep_running.sh && \
    chmod +x /root/build_and_keep_running.sh

# Set the new script as the CMD
CMD ["/root/build_and_keep_running.sh"]
