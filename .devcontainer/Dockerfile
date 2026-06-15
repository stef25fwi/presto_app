# Flutter SDK épinglé à une version précise (et NON au tag flottant ":stable")
# pour garantir que l'analyseur de l'IDE et la CLI utilisent exactement le
# même SDK. Cela évite les faux positifs (ex: const_with_non_const sur
# BorderRadius.circular) dus à une dérive de version entre rebuilds.
# Pour monter de version : changer ce tag puis relancer `flutter pub get`.
FROM ghcr.io/cirruslabs/flutter:3.44.0

# Install additional tools if needed
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends git curl unzip \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Configure Flutter for web
RUN flutter config --enable-web
