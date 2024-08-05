# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install required packages with retries
RUN apt-get clean && apt-get update && \
    apt-get install -y wget curl unzip automake build-essential file pkg-config git python \
    libtool libtinfo5 cmake openjdk-8-jre-headless clang --fix-missing && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up environment variables
ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_NDK_ROOT=/opt/android-ndk \
    ANDROID_HOME=/opt/android-sdk \
    FLUTTER_ROOT=/opt/flutter \
    PATH=${PATH}:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-ndk:/opt/flutter/bin

# Install Android SDK and NDK
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip -O android-sdk.zip && \
    unzip -q android-sdk.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm android-sdk.zip && \
    yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "platform-tools" "platforms;android-33" "build-tools;33.0.0" && \
    wget -q https://dl.google.com/android/repository/android-ndk-r17c-linux-x86_64.zip -O android-ndk.zip && \
    unzip -q android-ndk.zip -d /opt && \
    mv /opt/android-ndk-r17c ${ANDROID_NDK_ROOT} && \
    rm android-ndk.zip

# Install Flutter and checkout to a specific version
RUN git clone https://github.com/flutter/flutter.git ${FLUTTER_ROOT} && \
    cd ${FLUTTER_ROOT} && \
    git fetch --tags && \
    git checkout 2.10.0 && \
    flutter doctor

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Set up working directory
WORKDIR /app

# Increase Git's HTTP buffer size and add retry logic for cloning the repository
RUN git config --global http.postBuffer 104857600 && \
    (for i in $(seq 1 5); do git clone https://github.com/cake-tech/cake_wallet.git . && break || sleep 15; done) && \
    cd /app && \
    git fetch --all --tags && \
    git checkout tags/v4.19.1

# Generate keystore file
RUN keytool -genkey -v -keystore /root/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key -storepass your_store_password -keypass your_key_password -dname "CN=Your Name, OU=Your Organizational Unit, O=Your Organization, L=Your City, S=Your State, C=Your Country Code"

# Remove pubspec.lock to avoid conflicts
RUN find . -name pubspec.lock -exec rm -f {} \;

# Modify pubspec.yaml to fix intl dependency issue
RUN find . -name pubspec.yaml -print -exec sed -i 's/intl:.*$/intl: ^0.18.0/' {} \; && \
    echo "pubspec.yaml files updated" && \
    grep -R "intl: ^0.18.0" . || echo "Failed to update intl version"

# Build Cake Wallet
RUN mkdir -p /opt/android && \
    cd scripts/android && \
    ./install_ndk.sh && \
    bash -c "source ./app_env.sh cakewallet && \
    ./app_config.sh && \
    ./build_all.sh" && \
    cd ../../ && \
    flutter clean && \
    flutter pub get && \
    flutter pub upgrade --major-versions && \
    flutter packages pub run tool/generate_new_secrets.dart && \
    flutter packages pub run tool/generate_android_key_properties.dart keyAlias=key storeFile=/root/key.jks storePassword=your_store_password keyPassword=your_key_password && \
    flutter packages pub run tool/generate_localization.dart && \
    ./model_generator.sh && \
    flutter build apk --release

# Add SHA256 checksums for verification
RUN echo "4324fe3ee56762c012135884ff3ac99c7194ffaeabcb26d9359316fc2e0d1426  /app/build/app/outputs/flutter-apk/app-release.apk" > /app/checksums.txt && \
    sha256sum -c /app/checksums.txt

# Add release notes
RUN echo "Cake Wallet v4.19.1 Release Notes:" > /app/release_notes.txt && \
    echo "* Monero and Ethereum enhancements" >> /app/release_notes.txt && \
    echo "* Synchronization improvements" >> /app/release_notes.txt && \
    echo "* Exchange flow enhancements" >> /app/release_notes.txt && \
    echo "* Ledger improvements" >> /app/release_notes.txt && \
    echo "* Bug fixes" >> /app/release_notes.txt
