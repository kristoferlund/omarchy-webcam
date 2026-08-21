# Webcam Controls for Omarchy

Control any V4L2 webcam directly from the Omarchy bar. Webcam Controls gives you a live preview and automatically builds the right settings panel for each camera, from exposure and focus to color and framing.

## Features

- Live preview while the panel is open
- Capture-device picker
- Automatic detection of V4L2 capture devices
- Controls generated from each device's reported V4L2 controls
- Exposure, image, color, focus, framing, and device-specific groups
- Sliders, toggles, menus, action buttons, and raw value fields
- Read-only, inactive, grabbed, private, and compound controls
- Camera-reported default values
- Persistent device selection

Metadata-only `/dev/videoN` nodes are excluded. Multiple capture nodes from the same physical device remain available because they may provide different capabilities.

## Requirements

- Omarchy 4.0 or newer
- Qt Multimedia (`qt6-multimedia`)
- `v4l2-ctl` from `v4l-utils`
- A Linux V4L2 capture device

## Install

```sh
omarchy plugin add https://github.com/kristoferlund/omarchy-webcam.git --enable
```

## Bar Position

Move the widget to the left bar section:

```sh
omarchy bar move io.github.kristoferlund.webcam --section left
```

## Usage

- Left-click the camera icon to open or close the panel.
- Middle-click the icon to refresh devices and settings.
- Select a camera from the device menu.
- Double-click a slider's displayed value to restore its reported default.
- Press Escape to close the panel.

The preview stays at the top of the panel. The settings area grows to the available screen height and scrolls when necessary. Closing the panel stops the preview and releases the camera.

## Controls

The interface follows the type and flags reported by the camera:

| V4L2 control | Interface |
| --- | --- |
| Boolean or integer range `0..1` | Toggle |
| Menu or integer menu | Dropdown |
| Writable integer range | Slider |
| Button or write-only operation | Action button |
| Writable integer64, string, or bitmask | Value field |
| Read-only control | Value row |
| Compound or unsupported payload | Read-only value row |

Inactive and grabbed controls are disabled. Complex payloads are shown but cannot be edited generically through `v4l2-ctl`.

## Defaults

Default values come from the camera driver. A reset is available only when the control is writable, active, scalar, and has a reported default.

## Control Dependencies

The panel reads control flags again after pending changes have been applied. Controls marked `inactive` or `grabbed` by the driver are disabled.

Some cameras ignore controls in certain modes without reporting a dependency. Those controls remain enabled because V4L2 does not provide a general dependency graph.

## Device Selection

The selected `/dev/videoN` path is stored in the widget's entry in `~/.config/omarchy/shell.json`. Example entry:

```json
{
  "id": "io.github.kristoferlund.webcam",
  "device": "/dev/video2"
}
```

Device numbers can change after reconnecting hardware. Select the device again if its path changes.

## Development

Inspect available devices and controls:

```sh
./webcamctl devices
./webcamctl state
./webcamctl state /dev/video2
```

Run validation:

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml tests/tst_model.qml
qmltestrunner -input tests -import "$OMARCHY_PATH/shell" -o -,txt
bash -n webcamctl
```

## Security

Webcam Controls runs with user permissions inside `omarchy-shell`. `webcamctl` restricts device arguments to `/dev/videoN`, validates control names and values, and invokes `v4l2-ctl` without `eval`, `sh -c`, elevated privileges, network access, or background services.

## Remove

```sh
omarchy plugin remove io.github.kristoferlund.webcam
```

## License

MIT
