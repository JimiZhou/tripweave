# Contributing

Thank you for improving TripWeave.

## Development workflow

1. Fork the repository and create a focused branch.
2. Run `flutter pub get`, `flutter analyze`, and
   `flutter test --exclude-tags=real-e2e`.
3. Keep platform behavior local-first. A feature must not upload original
   media unless the user explicitly chooses that operation.
4. Never commit API keys, signing files, personal endpoints, test media, or
   generated release packages.
5. Open a pull request describing the user impact, platforms affected, and
   verification performed.

Official Android, Web, Windows, and macOS packages are built only by GitHub
Actions runners. Local builds are suitable for development, but are not
official release artifacts.

## Code style

- Format Dart with `dart format`.
- Keep visible product copy concise and avoid platform-specific assumptions in
  shared code.
- Add tests for state transitions, serialization, agent plans, and render
  fallback behavior.
- Preserve third-party license and source notices when updating media,
  fonts, FFmpeg, or vendored packages.
