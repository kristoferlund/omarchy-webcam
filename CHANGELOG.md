# Changelog

All notable changes to Webcam Controls are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The version in `manifest.json` matches the latest release.

## [Unreleased]

### Added

- A preview resolution picker in the panel, listing the sizes the device offers behind an Automatic default. The choice is saved as `resolution` and cleared when the capture device changes. ([#3](https://github.com/kristoferlund/omarchy-webcam/pull/3))

### Fixed

- The preview asks a capture card for a mode it can deliver. `Camera.cameraFormat` was never set, so Qt took the driver's first mode, and a RODE Streamer X fed 1080p lists 3840x2160 first and answers with its own "format not supported" card. The preview now picks the largest mode at or below 1920x1080 and applies it again after Qt clears it on activation and on a device switch. ([#3](https://github.com/kristoferlund/omarchy-webcam/pull/3))
- A capture card that reports no V4L2 controls shows a plain notice instead of an error. ([#3](https://github.com/kristoferlund/omarchy-webcam/pull/3))

## [0.1.1] - 2026-10-12

### Fixed

- Panel colors are themed again on Qt 6.12. Qt 6.12 adds a QtQuick `Color` type that shadowed the shell palette, so the panel now reads it as `Commons.Color`. This still works on Qt 6.11. ([#4](https://github.com/kristoferlund/omarchy-webcam/pull/4), thanks [@riclib](https://github.com/riclib))
- Closing the panel or reloading the shell no longer logs `Property 'applyState' of object Panel_QMLTYPE is not a function`. Deferred callbacks and device enumeration are skipped once the panel is destroyed. ([#2](https://github.com/kristoferlund/omarchy-webcam/pull/2), thanks [@olafkfreund](https://github.com/olafkfreund))

## [0.1.0] - 2026-08-21

Initial release.

### Added

- Bar widget with a live camera preview while the panel is open.
- Automatic detection of V4L2 capture devices, excluding metadata-only nodes, and a capture-device picker with a persistent selection.
- Settings generated from each device's reported V4L2 controls, grouped into exposure, image, color, focus, framing, and device-specific sections.
- Sliders, toggles, menus, action buttons, and raw value fields chosen from the control type, with read-only, inactive, grabbed, private, and compound controls handled.
- Reset to the camera-reported default by double-clicking a slider value.
- `webcamctl` helper that restricts device arguments to `/dev/videoN` and validates control names and values before calling `v4l2-ctl`.
- Device names and menu labels are sanitized before they are rendered.

[Unreleased]: https://github.com/kristoferlund/omarchy-webcam/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/kristoferlund/omarchy-webcam/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/kristoferlund/omarchy-webcam/releases/tag/v0.1.0
