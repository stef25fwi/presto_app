FROM ghcr.io/cirruslabs/flutter:stable

# Install additional tools if needed
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends git curl unzip \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Configure Flutter for web
RUN flutter config --enable-web
