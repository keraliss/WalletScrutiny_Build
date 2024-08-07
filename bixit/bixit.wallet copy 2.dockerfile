# Use an Ubuntu base image
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y

# Install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    openjdk-17-jdk \
    git \
    libc6-dev-i386 \
    lib32z1 \
    lib32stdc++6 \
    openssl

# Install Node.js 18 and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs && \
    npm install -g yarn

# Install Android SDK
ENV ANDROID_HOME /opt/android-sdk
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && cd ${ANDROID_HOME}/cmdline-tools && \
wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
unzip commandlinetools-linux-9477386_latest.zip && \
mv cmdline-tools latest && \
rm commandlinetools-linux-9477386_latest.zip

# Set up Android SDK
ENV PATH ${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin

# Install necessary Android SDK components
RUN yes | sdkmanager --sdk_root=${ANDROID_HOME} \
    "platform-tools" \
    "platforms;android-30" \
    "build-tools;30.0.3" \
    "extras;android;m2repository" \
    "extras;google;m2repository" \
    "ndk;23.1.7779620"

# Manually download and install the correct bundletool
RUN wget https://github.com/google/bundletool/releases/download/1.8.2/bundletool-all-1.8.2.jar -O /opt/android-sdk/cmdline-tools/latest/bin/bundletool.jar

# Add bundletool to the PATH
ENV PATH ${PATH}:/opt/android-sdk/cmdline-tools/latest/bin

# Set the working directory
WORKDIR /app

# Clone the correct Blixt Wallet repository
RUN git clone https://github.com/hsjoberg/blixt-wallet.git .

RUN yarn cache clean
RUN yarn install --ignore-engines

# Install Node packages
RUN yarn install --ignore-engines

# Install LND binary
RUN mkdir -p /app/android/app/libs && \
    wget https://github.com/hsjoberg/blixt-wallet/releases/download/v0.6.9-420/Lndmobile.aar -O /app/android/app/libs/Lndmobile.aar && \
    ls -l /app/android/app/libs/Lndmobile.aar

# Generate proto files
RUN yarn gen-proto --ignore-engines

# Set up environment variables
ENV PATH ${PATH}:${ANDROID_HOME}/platform-tools

# Pre-download Gradle
RUN cd /app/android && \
    ./gradlew --version

# Set appropriate permissions
RUN chmod +x /app/android/gradlew

# Increase Gradle daemon timeout
RUN mkdir -p /root/.gradle && \
    echo "org.gradle.daemon.idletimeout=3600000" >> /root/.gradle/gradle.properties

# Print out contents of key directories
RUN ls -R /app/android

# Expose Metro bundler port
EXPOSE 8081

# Build the project, start Metro bundler, and run the Android app
CMD ["sh", "-c", "cd android && ./gradlew assembleDebug --stacktrace && yarn start-metro & yarn android:mainnet-debug"]
