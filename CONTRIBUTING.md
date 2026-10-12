# Contributing

Thanks for helping improve Webcam Controls. Bug reports, fixes, and support for more cameras are all welcome.

## Before You Start

- **Bugs:** open an issue with the bug report template. Include your camera and the output of `./webcamctl state`. Most bugs depend on what the driver reports.
- **Small fixes:** go straight to a pull request.
- **New features or larger changes:** open an issue first so we can agree on the approach before you spend time on it.
- **Security issues:** do not open a public issue. See [SECURITY.md](SECURITY.md).

## Project Principles

Changes should fit these principles:

- **Generic over device-specific.** The panel is built from what V4L2 reports. Prefer fixes that work for every camera with the same behavior over special cases for one model.
- **Follow the driver.** Use the types, flags, ranges, and defaults the camera reports instead of hardcoded values.
- **Keep `webcamctl` narrow.** It runs with user permissions only. Do not add `eval`, `sh -c`, `sudo` or other privilege escalation, network access, or background services. Validate every argument passed to `v4l2-ctl`.
- **Release the camera.** Closing the panel must stop the preview and free the device.
- **Stay compatible.** Support Omarchy 4.0 and newer, and both current and upcoming Qt releases where possible.

## Development Setup

Clone the repository and install it from your checkout:

```sh
git clone https://github.com/kristoferlund/omarchy-webcam.git
cd omarchy-webcam
omarchy plugin add "$PWD" --enable
```

Inspect the devices and controls the plugin sees:

```sh
./webcamctl devices
./webcamctl state /dev/video2
```

## Validation

Run these before opening a pull request:

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml tests/tst_model.qml
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests -o -,txt
bash -n webcamctl
shellcheck webcamctl
```

Use the Qt 6 tools from `/usr/lib/qt6/bin`. If Qt 5 is also installed, `qmllint` and `qmltestrunner` on your `PATH` may be the Qt 5 versions. `qmllint` warns about shell types it cannot resolve. Those warnings are expected, but check for new warnings in the lines you changed.

CI runs the model tests, the shell checks, and a manifest check on every pull request. It cannot run the plugin inside `omarchy-shell` or use a real camera, so also test your change in a running shell with a real device.

Parsing logic belongs in `Model.js`, where it can be tested. If you change how `v4l2-ctl` output is parsed, add a test case in `tests/tst_model.qml` with the output that triggered the change.

## Pull Requests

- Keep each pull request focused on one change.
- Explain what was wrong and how you tested it: which camera, Omarchy version, and Qt version.
- Include a screenshot for visible UI changes.
- Add an entry under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for user-facing changes.
- Leave the `version` in `manifest.json` alone. The maintainer bumps it when releasing.
- Write commit subjects in the imperative mood and keep them under about 72 characters, for example `Guard deferred callbacks after panel destruction`.

AI-assisted contributions are welcome. You are responsible for every line you submit, so review the code yourself and test it on real hardware.

Pull requests are usually squash-merged.

## Releases

The maintainer releases by moving the `Unreleased` entries in `CHANGELOG.md` into a new version section, bumping `version` in `manifest.json`, tagging `vX.Y.Z`, and publishing a GitHub release with the changelog notes.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
