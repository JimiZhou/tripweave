# Changelog

All notable changes are documented here. TripWeave follows semantic versioning
for public releases.

## Unreleased

- Added a device-local sign-in gate: travelers create an on-device profile,
  and an admin role is unlocked by a salted-passcode set on first use.
- Added admin-managed model presets: named editing-service configurations that
  travelers apply with one tap and without seeing the API key; one preset can
  be marked default and is auto-applied on new sessions. Deployments can also
  ship built-in presets via the `TRIPWEAVE_MODEL_PRESETS` dart-define.
- Branded the web entry point: launch splash with the TripWeave mark, theme
  color, Open Graph metadata, and a zh-CN manifest.
- Session restore now happens behind a branded in-app splash, and the desktop
  navigation shows the signed-in profile.

## 0.1.5 - 2026-07-20

- Added the guided import, curation, analysis, template, editing, and export
  flow.
- Added three explainable editing plans and user-directed replanning.
- Combined compact preview, timeline, music, and clip-range editing.
- Added persisted completed journeys with missing-source handling.
- Added GPU portrait presets and hardware-first encoding probes.
- Added on-demand CC0 music with visible author, source, and license metadata.
- Added Android, Web, Windows, and macOS runner builds plus GitHub Pages.
- Removed all hosted-service defaults, managed beta provisioning, private
  deployment source, bundled music files, and maintainer-specific endpoints
  from the public source tree.
