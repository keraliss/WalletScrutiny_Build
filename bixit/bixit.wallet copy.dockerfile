# Use an Ubuntu base image
FROM ubuntu:20.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    openjdk-17-jdk \
    git \
    libc6-dev-i386 \
    lib32z1 \
    lib32stdc++6

# Install Node.js 18 and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs && \
    npm install -g yarn

# Install Android SDK
ENV ANDROID_HOME /opt/android-sdk
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && cd ${ANDROID_HOME}/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip && \
    unzip commandlinetools-linux-8512546_latest.zip && \
    mv cmdline-tools latest && \
    rm commandlinetools-linux-8512546_latest.zip

# Set up Android SDK
ENV PATH ${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin

# Use sdkmanager to install necessary Android SDK components
RUN yes | sdkmanager --sdk_root=${ANDROID_HOME} \
    "platform-tools" \
    "platforms;android-30" \
    "build-tools;30.0.3" \
    "extras;android;m2repository" \
    "extras;google;m2repository"

# Install Gradle
ENV GRADLE_VERSION 7.3.3
RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp && \
    unzip -d /opt/gradle /tmp/gradle-${GRADLE_VERSION}-bin.zip && \
    ln -s /opt/gradle/gradle-${GRADLE_VERSION} /opt/gradle/latest

ENV GRADLE_HOME /opt/gradle/latest
ENV PATH ${PATH}:${GRADLE_HOME}/bin

# Set the working directory
WORKDIR /app

# Clone the correct Blixt Wallet repository
RUN git clone https://github.com/hsjoberg/blixt-wallet.git .

# Install Node packages
RUN yarn install --ignore-engines

# Install LND binary
RUN mkdir -p /app/android/app/lndmobile && \
wget https://github.com/hsjoberg/blixt-wallet/releases/download/v0.6.9-420/Lndmobile.aar -O /app/android/app/lndmobile/lnd.aar && \
    ls -l /app/android/app/lndmobile/lnd.aar

# Generate proto files
RUN yarn gen-proto --ignore-engines

# Set up environment variables
ENV PATH ${PATH}:${ANDROID_HOME}/platform-tools

# Print out contents of key directories
RUN ls -R /app/android

# Expose Metro bundler port
EXPOSE 8081

# Build the project, start Metro bundler, and run the Android app
CMD ["sh", "-c", "cd android && ./gradlew assembleDebug --stacktrace && yarn start-metro & yarn android:mainnet-debug"]