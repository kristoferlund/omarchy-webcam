import QtQuick 2.15
import QtTest 1.3
import "../Model.js" as Model

TestCase {
  name: "WebcamControlsModel"

  readonly property string sampleDevices: [
    "DEVICE\t/dev/video2\tUSB Camera\tusb-0000:00:14.0-3 | pci0000:00/usb1/1-3",
    "DEVICE\t/dev/video3\tUSB Camera\tusb-0000:00:14.0-3 | pci0000:00/usb1/1-3",
    "BROKEN\t/dev/video4\tIgnored",
    "DEVICE\tnot-a-device\tIgnored\tbad"
  ].join("\n")

  readonly property string sampleState: [
    "DEVICE\t/dev/video2\tUSB Camera\tusb-0000:00:14.0-3 | pci0000:00/usb1/1-3",
    "",
    "User Controls",
    "",
    "  white_balance_automatic 0x0098090c (bool) : default=1 value=1",
    "  power_line_frequency 0x00980918 (menu) : min=0 max=2 default=2 value=1 (50 Hz)",
    "    0: Disabled",
    "    1: 50 Hz",
    "    2: 60 Hz",
    "  white_balance_temperature 0x0098091a (int) : min=2800 max=7500 step=10 default=5000 value=5000 flags=inactive, grabbed, has-min-max",
    "  backlight_compensation 0x0098091c (int) : min=0 max=1 step=1 default=0 value=0 flags=has-min-max",
    "  device_serial 0x009819e1 (str) : min=0 max=64 step=1 value='serial number 42' flags=read-only, volatile",
    "  status_mask 0x009819e2 (bitmask) : max=0xffffffff default=0x0 value=0x80000000",
    "  noise_reduction 0x009819e4 (int) : min=0 max=10 step=1 default=5 value=4",
    "  frame_counter 0x009819e3 (int64) : min=0 max=9223372036854775807 step=1 default=0 value=9223372036854775807 flags=read-only",
    "",
    "Camera Controls",
    "",
    "  auto_exposure 0x009a0901 (menu) : min=0 max=3 default=3 value=3 (Aperture Priority Mode)",
    "    1: Manual Mode",
    "    3: Aperture Priority Mode",
    "  exposure_time_absolute 0x009a0902 (int) : min=1 max=2500 step=1 default=156 value=200",
    "  iso_sensitivity 0x009a0917 (intmenu) : min=0 max=2 default=0 value=1",
    "    0: 100 (0x64)",
    "    1: 200 (0xc8)",
    "    2: 400 (0x190)",
    "  auto_focus_start 0x009a091c (button) : flags=write-only",
    "  detected_faces 0x009a0920 (area) : value=640x480 flags=has-payload, read-only",
    "",
    "Private Controls",
    "",
    "  vendor_strength 0x08000001 (int) : min=0 max=10 step=1 default=5 value=7 flags=private",
    "  mystery_payload 0x08000002 (mystery) : value=opaque flags=private, inactive"
  ].join("\n")

  function test_parseDevicesKeepsCaptureNodesWithSameName() {
    var devices = Model.parseDevices(sampleDevices)
    compare(devices.length, 2)
    compare(devices[0].device, "/dev/video2")
    compare(devices[1].device, "/dev/video3")
    compare(devices[0].name, "USB Camera")
    verify(devices[0].details.indexOf("usb-0000") !== -1)

    var options = Model.deviceOptions(devices, true)
    compare(options.length, 3)
    compare(options[0].value, "")
    compare(options[1].label, "USB Camera · /dev/video2")
    verify(options[1].label.indexOf("usb-0000") === -1)
  }

  function test_externalOptionLabelsCannotContainMarkup() {
    compare(Model.safeOptionLabel("<img src='file:///tmp/x'>&"), "‹img src='file:///tmp/x'›＆")
  }

  function test_deviceListComparisonIncludesParsedIdentity() {
    var devices = Model.parseDevices(sampleDevices)
    var sameDevices = Model.parseDevices(sampleDevices)
    verify(Model.deviceListsEqual(devices, sameDevices))
    verify(Model.deviceListsEqual([], []))

    var changedDetails = Model.parseDevices(sampleDevices.replace("pci0000:00/usb1/1-3", "pci0000:00/usb1/1-4"))
    verify(!Model.deviceListsEqual(devices, changedDetails))
    verify(!Model.deviceListsEqual(devices, devices.slice(0, 1)))
    verify(!Model.deviceListsEqual(devices, [devices[1], devices[0]]))
  }

  function test_parseStateIdentityAndMenus() {
    var state = Model.parseState(sampleState)
    compare(state.device, "/dev/video2")
    compare(state.deviceName, "USB Camera")
    verify(state.deviceDetails.indexOf("pci0000") !== -1)
    compare(state.controls.length, 15)

    var frequency = Model.control(state.controls, "power_line_frequency")
    compare(frequency.id, "0x00980918")
    compare(frequency.type, "menu")
    compare(frequency.value, 1)
    compare(frequency.options.length, 3)
    compare(frequency.options[1].label, "50 Hz")

    var iso = Model.control(state.controls, "iso_sensitivity")
    compare(iso.type, "intmenu")
    compare(iso.options.length, 3)
    compare(iso.options[2].value, "2")
    compare(Model.renderKind(iso), "menu")
  }

  function test_flagsAndMetadata() {
    var controls = Model.parseState(sampleState).controls
    var temperature = Model.control(controls, "white_balance_temperature")
    verify(temperature.inactive)
    verify(temperature.grabbed)
    verify(temperature.flags.indexOf("has-min-max") !== -1)
    compare(Model.limitationLabel(temperature), "Currently inactive because of another camera setting.")

    var serial = Model.control(controls, "device_serial")
    compare(serial.type, "string")
    compare(serial.value, "serial number 42")
    verify(serial.readOnly)
    verify(serial.volatile)
    compare(serial.category, "Advanced")
    compare(Model.renderKind(serial), "value")
    compare(Model.limitationLabel(serial), "Reported read-only by the device.")

    var action = Model.control(controls, "auto_focus_start")
    verify(action.writeOnly)
    verify(!action.hasValue)
    compare(action.value, null)
    compare(Model.valueLabel(action), "Not reported")
    compare(Model.renderKind(action), "action")

    var area = Model.control(controls, "detected_faces")
    verify(area.compound)
    verify(area.readOnly)
    compare(Model.renderKind(area), "value")
    verify(Model.limitationLabel(area).indexOf("payload") !== -1)

    compare(Model.limitationLabel(Model.control(controls, "exposure_time_absolute")), "")
  }

  function test_precisionHexAndRawEditing() {
    var controls = Model.parseState(sampleState).controls
    var counter = Model.control(controls, "frame_counter")
    compare(typeof counter.value, "string")
    compare(counter.value, "9223372036854775807")
    compare(counter.maximum, "9223372036854775807")

    var mask = Model.control(controls, "status_mask")
    compare(mask.value, "0x80000000")
    compare(mask.rawValue, "0x80000000")
    verify(Model.canEditRaw(mask))
    compare(Model.renderKind(mask), "rawEdit")
  }

  function test_binaryControlsRenderAsToggles() {
    var controls = Model.parseState(sampleState).controls
    verify(Model.isToggle(Model.control(controls, "white_balance_automatic")))
    verify(Model.isToggle(Model.control(controls, "backlight_compensation")))
    verify(!Model.isToggle(Model.control(controls, "exposure_time_absolute")))
    verify(!Model.isToggle(Model.control(controls, "power_line_frequency")))
  }

  function test_defaultResetEligibility() {
    var controls = Model.parseState(sampleState).controls

    verify(Model.canReset(Model.control(controls, "exposure_time_absolute")))
    verify(Model.canReset(Model.control(controls, "backlight_compensation")))
    verify(Model.canReset(Model.control(controls, "power_line_frequency")))
    verify(!Model.canReset(Model.control(controls, "white_balance_temperature")))
    verify(!Model.canReset(Model.control(controls, "device_serial")))
    verify(!Model.canReset(Model.control(controls, "auto_focus_start")))
    verify(!Model.canReset(Model.control(controls, "detected_faces")))
  }

  function test_genericLabelsCategoriesAndUnits() {
    var controls = Model.parseState(sampleState).controls
    compare(Model.control(controls, "iso_sensitivity").category, "Exposure")
    compare(Model.control(controls, "auto_focus_start").category, "Focus")
    compare(Model.control(controls, "vendor_strength").category, "Device-specific")
    compare(Model.control(controls, "mystery_payload").category, "Device-specific")
    compare(Model.control(controls, "noise_reduction").category, "Advanced")
    verify(Model.control(controls, "vendor_strength").privateControl)
    verify(Model.control(controls, "mystery_payload").privateControl)
    verify(Model.control(controls, "vendor_strength")["private"])
    compare(Model.control(controls, "mystery_payload").label, "Mystery Payload")

    var exposure = Model.control(controls, "exposure_time_absolute")
    compare(Model.valueLabel(exposure), "20 ms")
    compare(Model.valueLabel({ name: "zoom_absolute", type: "int", value: 120, hasValue: true, writeOnly: false }), "120")
  }

  function test_standardGenericControlCatalog() {
    var expected = {
      focus_auto: "Focus",
      gamma: "Image",
      hue: "Color",
      hue_auto: "Color",
      horizontal_flip: "Framing",
      vertical_flip: "Framing",
      rotate: "Framing",
      color_effects: "Color",
      hdr: "Exposure",
      wide_dynamic_range: "Exposure",
      image_stabilization: "Framing",
      iso_sensitivity: "Exposure",
      exposure_metering: "Exposure",
      auto_exposure_bias: "Exposure",
      scene_mode: "Exposure"
    }
    for (var name in expected) {
      verify(Model.displayLabel(name) !== name)
      compare(Model.controlCategory(name, false), expected[name])
    }
  }

  function test_sliderValuesSnapToReportedSteps() {
    var controls = Model.parseState(sampleState).controls
    var temperature = Model.control(controls, "white_balance_temperature")

    compare(Model.snapValue(temperature, 5004), 5000)
    compare(Model.snapValue(temperature, 5006), 5010)
    compare(Model.snapValue(temperature, 1000), 2800)
    compare(Model.snapValue(temperature, 9000), 7500)
  }

  function test_noControlsOmittedFromGroups() {
    var controls = Model.parseState(sampleState).controls
    var groups = Model.groupControls(controls)
    var seen = {}
    var count = 0
    for (var i = 0; i < groups.length; i++) {
      for (var j = 0; j < groups[i].controls.length; j++) {
        var name = groups[i].controls[j].name
        verify(!seen[name], "Control appeared in more than one group: " + name)
        seen[name] = true
        count++
      }
    }
    compare(count, controls.length)
    for (var k = 0; k < controls.length; k++) verify(seen[controls[k].name])
  }

  function test_updatesDoNotMutateOriginal() {
    var controls = Model.parseState(sampleState).controls
    var updated = Model.withValue(controls, "exposure_time_absolute", "333")
    compare(Model.control(updated, "exposure_time_absolute").value, 333)
    compare(Model.valueLabel(Model.control(updated, "exposure_time_absolute")), "33.3 ms")
    compare(Model.control(controls, "exposure_time_absolute").value, 200)
  }
}
