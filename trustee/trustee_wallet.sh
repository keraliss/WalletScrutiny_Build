#!/bin/bash

set -e

# Constants
REPO_URL="https://github.com/trustee-wallet/trusteeWallet.git"
VERSION="1.51.5"
BUILD_DIR="$(pwd)/trustee_wallet_build"

# Clone repository if it doesn't exist
if [ ! -d "$BUILD_DIR" ]; then
    git clone $REPO_URL $BUILD_DIR
fi

cd $BUILD_DIR

# Checkout specific version
git checkout v$VERSION  # Assuming version tags are prefixed with 'v'

# Build Docker image
docker build -f docker/Dockerfile.verifyandroidbuild -t trustee-wallet-verify .

# Run verification process
docker run --rm -v $(pwd):/trustee trustee-wallet-verify /bin/bash -c "
    cd /trustee && \
    ./docker/verify_android_build.sh && \
    diff --recursive --brief fromBuild fromGoogle
"

# Check the exit code of the Docker run command
if [ $? -eq 0 ]; then
    echo "Verification successful. Builds are identical."
else
    echo "Verification failed. There are differences between the builds."
    echo "You may want to run a more detailed diff or analyze the differences manually."
fi

# Cleanup
echo "Do you want to remove the Docker image and build directory? (y/n)"
read answer
if [ "$answer" = "y" ]; then
    docker rmi trustee-wallet-verify
    rm -rf $BUILD_DIR
    echo "Cleanup completed."
else
    echo "Cleanup skipped. You can manually remove the Docker image with 'docker rmi trustee-wallet-verify'"
    echo "and the build directory at $BUILD_DIR"
fi