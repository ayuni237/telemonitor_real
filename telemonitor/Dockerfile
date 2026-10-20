# App image: analysis, tests and Android build of the Flutter app, with the
# Flutter version used in development. The app folder is mounted at /app.
# Running the app needs a device or emulator, outside Docker.
ARG FLUTTER_VERSION=3.44.2
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION}

WORKDIR /app
CMD ["bash", "-c", "flutter pub get && flutter analyze && flutter test"]
