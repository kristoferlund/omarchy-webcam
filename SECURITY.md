# Security Policy

## Supported Versions

Security fixes are released for the latest version only.

## Reporting a Vulnerability

Do not open a public issue for security problems. Instead, report them privately through GitHub's [private vulnerability reporting](https://github.com/kristoferlund/omarchy-webcam/security/advisories/new).

Please include:

- What the issue is and what an attacker could do with it.
- Steps or a proof of concept to reproduce it.
- The plugin version, Omarchy version, and camera, if relevant.

You should get a response within a week. Once a fix is released, the advisory is published and you are credited, unless you prefer otherwise.

## Scope

Webcam Controls runs with user permissions inside `omarchy-shell`. The main security boundary is `webcamctl`, which takes device paths and control values from the panel and passes them to `v4l2-ctl`. Issues worth reporting include:

- Command or argument injection through device paths, device names, control names, or control values.
- Access to files or devices outside `/dev/videoN`.
- Markup or text injection through device names or menu labels reported by a driver.
