.pragma library

var labels = {
  auto_exposure: "Exposure mode",
  exposure_auto: "Exposure mode",
  exposure_time_absolute: "Exposure time",
  exposure_absolute: "Exposure time",
  exposure_dynamic_framerate: "Dynamic frame rate",
  exposure_auto_priority: "Dynamic frame rate",
  exposure_metering: "Exposure metering",
  auto_exposure_bias: "Exposure bias",
  exposure_bias: "Exposure bias",
  iso_sensitivity: "ISO sensitivity",
  iso_sensitivity_auto: "Automatic ISO",
  scene_mode: "Scene mode",
  gain: "Gain",
  backlight_compensation: "Backlight compensation",
  wide_dynamic_range: "Wide dynamic range",
  hdr: "HDR",
  hdr_sensor_mode: "HDR sensor mode",
  brightness: "Brightness",
  contrast: "Contrast",
  saturation: "Saturation",
  sharpness: "Sharpness",
  gamma: "Gamma",
  hue: "Hue",
  hue_auto: "Automatic hue",
  black_level: "Black level",
  white_balance_automatic: "Automatic white balance",
  auto_white_balance: "Automatic white balance",
  white_balance_temperature: "Color temperature",
  red_balance: "Red balance",
  blue_balance: "Blue balance",
  power_line_frequency: "Anti-flicker",
  color_effects: "Color effect",
  colorfx: "Color effect",
  colorfx_cbcr: "Color effect chroma",
  focus_absolute: "Focus",
  focus_relative: "Relative focus",
  focus_auto: "Autofocus",
  auto_focus_start: "Start autofocus",
  auto_focus_stop: "Stop autofocus",
  auto_focus_status: "Autofocus status",
  zoom_absolute: "Zoom",
  zoom_relative: "Relative zoom",
  zoom_continuous: "Continuous zoom",
  pan_absolute: "Pan",
  pan_relative: "Relative pan",
  pan_speed: "Pan speed",
  tilt_absolute: "Tilt",
  tilt_relative: "Relative tilt",
  tilt_speed: "Tilt speed",
  horizontal_flip: "Horizontal flip",
  vertical_flip: "Vertical flip",
  rotate: "Rotation",
  image_stabilization: "Image stabilization",
  privacy: "Privacy",
  test_pattern: "Test pattern"
}

var categories = {
  auto_exposure: "Exposure",
  exposure_auto: "Exposure",
  exposure_time_absolute: "Exposure",
  exposure_absolute: "Exposure",
  exposure_dynamic_framerate: "Exposure",
  exposure_auto_priority: "Exposure",
  exposure_metering: "Exposure",
  auto_exposure_bias: "Exposure",
  exposure_bias: "Exposure",
  iso_sensitivity: "Exposure",
  iso_sensitivity_auto: "Exposure",
  scene_mode: "Exposure",
  gain: "Exposure",
  backlight_compensation: "Exposure",
  wide_dynamic_range: "Exposure",
  hdr: "Exposure",
  hdr_sensor_mode: "Exposure",
  brightness: "Image",
  contrast: "Image",
  saturation: "Image",
  sharpness: "Image",
  gamma: "Image",
  black_level: "Image",
  hue: "Color",
  hue_auto: "Color",
  white_balance_automatic: "Color",
  auto_white_balance: "Color",
  white_balance_temperature: "Color",
  red_balance: "Color",
  blue_balance: "Color",
  power_line_frequency: "Color",
  color_effects: "Color",
  colorfx: "Color",
  colorfx_cbcr: "Color",
  focus_absolute: "Focus",
  focus_relative: "Focus",
  focus_auto: "Focus",
  auto_focus_start: "Focus",
  auto_focus_stop: "Focus",
  auto_focus_status: "Focus",
  zoom_absolute: "Framing",
  zoom_relative: "Framing",
  zoom_continuous: "Framing",
  pan_absolute: "Framing",
  pan_relative: "Framing",
  pan_speed: "Framing",
  tilt_absolute: "Framing",
  tilt_relative: "Framing",
  tilt_speed: "Framing",
  horizontal_flip: "Framing",
  vertical_flip: "Framing",
  rotate: "Framing",
  image_stabilization: "Framing",
  privacy: "Framing",
  test_pattern: "Advanced"
}

var groupOrder = ["Exposure", "Image", "Color", "Focus", "Framing", "Advanced", "Device-specific"]

function displayLabel(name) {
  if (labels[name]) return labels[name]
  var words = String(name || "").replace(/_/g, " ").split(" ")
  for (var i = 0; i < words.length; i++) {
    if (words[i].length > 0)
      words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1)
  }
  return words.join(" ")
}

function safeOptionLabel(value) {
  return String(value || "")
    .replace(/&/g, "＆")
    .replace(/</g, "‹")
    .replace(/>/g, "›")
}

function normalizeType(type) {
  var value = String(type || "").toLowerCase().replace(/^\s+|\s+$/g, "")
  if (value === "integer") return "int"
  if (value === "boolean") return "bool"
  if (value === "str") return "string"
  if (value === "integer64") return "int64"
  if (value === "integer-menu" || value === "integer_menu") return "intmenu"
  return value
}

function fieldToken(body, key) {
  var pattern = new RegExp("(?:^|\\s)" + key + "=(\\\"(?:\\\\.|[^\\\"])*\\\"|'(?:\\\\.|[^'])*'|[^\\s]+)")
  var match = String(body || "").match(pattern)
  return match ? match[1].replace(/,$/, "") : null
}

function unquote(value) {
  var text = String(value)
  if (text.length >= 2 && ((text.charAt(0) === "'" && text.charAt(text.length - 1) === "'")
      || (text.charAt(0) === "\"" && text.charAt(text.length - 1) === "\"")))
    return text.slice(1, -1).replace(/\\(['"\\])/g, "$1")
  return text
}

function typedValue(token, type) {
  if (token === null) return null
  var text = unquote(token)
  if (type === "string" || type === "int64" || type === "bitmask" || /^-?0x/i.test(text)) return text
  if (/^-?\d+$/.test(text)) {
    var number = Number(text)
    if (isFinite(number) && Math.abs(number) <= 9007199254740991) return number
  }
  return text
}

function parseFlags(body) {
  var match = String(body || "").match(/(?:^|\s)flags=(.*)$/)
  if (!match) return []
  var parts = match[1].split(",")
  var result = []
  for (var i = 0; i < parts.length; i++) {
    var flag = parts[i].replace(/^\s+|\s+$/g, "").toLowerCase().replace(/_/g, "-")
    if (flag !== "") result.push(flag)
  }
  return result
}

function hasFlag(flags, name) {
  return flags.indexOf(name) !== -1
}

function controlCategory(name, isPrivate) {
  if (isPrivate) return "Device-specific"
  if (!labels[name]) return "Advanced"
  return categories[name] || "Advanced"
}

function parseDevices(raw) {
  var lines = String(raw || "").split("\n")
  var result = []
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].indexOf("DEVICE\t") !== 0) continue
    var parts = lines[i].split("\t")
    if (parts.length < 3 || !/^\/dev\/video\d+$/.test(parts[1])) continue
    result.push({
      device: parts[1],
      name: parts[2] || parts[1],
      details: parts.length > 3 ? parts.slice(3).join(" ") : ""
    })
  }
  return result
}

function deviceListsEqual(left, right) {
  var first = left || []
  var second = right || []
  if (first.length !== second.length) return false
  for (var i = 0; i < first.length; i++) {
    if (String(first[i].device || "") !== String(second[i].device || "")
        || String(first[i].name || "") !== String(second[i].name || "")
        || String(first[i].details || "") !== String(second[i].details || "")) return false
  }
  return true
}

function parseState(raw) {
  var lines = String(raw || "").split("\n")
  var result = { device: "", deviceName: "", deviceDetails: "", controls: [] }
  var current = null
  var section = ""

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.indexOf("DEVICE\t") === 0) {
      var deviceParts = line.split("\t")
      result.device = deviceParts.length > 1 ? deviceParts[1] : ""
      result.deviceName = deviceParts.length > 2 ? deviceParts[2] : ""
      result.deviceDetails = deviceParts.length > 3 ? deviceParts.slice(3).join(" ") : ""
      continue
    }

    var controlMatch = line.match(/^\s*([A-Za-z0-9_]+)\s+(0x[0-9a-fA-F]+)\s+\(([^)]+)\)\s*:\s*(.*)$/)
    if (controlMatch) {
      var body = controlMatch[4]
      var type = normalizeType(controlMatch[3])
      var flags = parseFlags(body)
      var rawValue = fieldToken(body, "value")
      var rawMinimum = fieldToken(body, "min")
      var rawMaximum = fieldToken(body, "max")
      var rawStep = fieldToken(body, "step")
      var rawDefault = fieldToken(body, "default")
      var privateControl = hasFlag(flags, "private") || /private/i.test(section) || /^0x0?800/i.test(controlMatch[2])
      var compound = hasFlag(flags, "has-payload") || type === "area" || type === "rect"
        || type === "u8" || type === "u16" || type === "u32" || type === "compound"
      if (compound || ["int", "bool", "menu", "intmenu", "int64", "string", "bitmask", "button"].indexOf(type) === -1) {
        var payloadMatch = body.match(/(?:^|\s)value=(.*?)(?:\s+flags=|$)/)
        if (payloadMatch) rawValue = payloadMatch[1].replace(/^\s+|\s+$/g, "")
      }
      current = {
        name: controlMatch[1],
        id: controlMatch[2],
        type: type,
        label: displayLabel(controlMatch[1]),
        category: controlCategory(controlMatch[1], privateControl),
        minimum: typedValue(rawMinimum, type),
        maximum: typedValue(rawMaximum, type),
        step: typedValue(rawStep, type),
        defaultValue: typedValue(rawDefault, type),
        value: typedValue(rawValue, type),
        rawDefault: rawDefault,
        rawValue: rawValue,
        hasValue: rawValue !== null,
        flags: flags,
        readOnly: hasFlag(flags, "read-only"),
        writeOnly: hasFlag(flags, "write-only"),
        inactive: hasFlag(flags, "inactive"),
        grabbed: hasFlag(flags, "grabbed"),
        volatile: hasFlag(flags, "volatile"),
        "private": privateControl,
        privateControl: privateControl,
        compound: compound,
        options: []
      }
      result.controls.push(current)
      continue
    }

    var optionMatch = line.match(/^\s+(-?(?:0x[0-9a-fA-F]+|\d+)):\s+(.+)$/)
    if (optionMatch && current && (current.type === "menu" || current.type === "intmenu")) {
      current.options.push({
        value: optionMatch[1],
        label: safeOptionLabel(optionMatch[2].replace(/^\s+|\s+$/g, ""))
      })
      continue
    }

    if (/^\S.*Controls\s*$/.test(line)) section = line.replace(/^\s+|\s+$/g, "")
  }

  return result
}

function groupControls(controls) {
  var buckets = {}
  var groups = []
  for (var i = 0; i < groupOrder.length; i++) buckets[groupOrder[i]] = []
  for (var j = 0; j < controls.length; j++) {
    var category = controls[j].category || "Device-specific"
    if (!buckets[category]) buckets[category] = []
    buckets[category].push(controls[j])
  }
  for (var k = 0; k < groupOrder.length; k++) {
    var title = groupOrder[k]
    if (buckets[title].length > 0) groups.push({ title: title.toUpperCase(), controls: buckets[title] })
  }
  for (var extra in buckets) {
    if (groupOrder.indexOf(extra) === -1 && buckets[extra].length > 0)
      groups.push({ title: String(extra).toUpperCase(), controls: buckets[extra] })
  }
  return groups
}

function isToggle(control) {
  if (!control) return false
  if (control.type === "bool") return true
  return control.type === "int"
    && Number(control.minimum) === 0
    && Number(control.maximum) === 1
    && Number(control.step) === 1
}

function isBlocked(control) {
  return !control || control.readOnly || control.inactive || control.grabbed
}

function snapValue(control, value) {
  if (!control) return Math.round(Number(value))
  var minimum = Number(control.minimum)
  var maximum = Number(control.maximum)
  var step = Math.max(1, Number(control.step) || 1)
  var numeric = Number(value)
  if (!isFinite(numeric)) return minimum
  var snapped = minimum + Math.round((numeric - minimum) / step) * step
  return Math.max(minimum, Math.min(maximum, snapped))
}

function canReset(control) {
  if (!control || isBlocked(control) || control.writeOnly || control.compound) return false
  if (control.rawDefault === null || control.rawDefault === undefined) return false
  return ["int", "bool", "menu", "intmenu", "int64", "bitmask"].indexOf(control.type) !== -1
}

function canEditRaw(control) {
  if (!control || isBlocked(control) || control.compound || control.writeOnly) return false
  return control.type === "int64" || control.type === "string" || control.type === "bitmask"
}

function renderKind(control) {
  if (!control) return "value"
  if (control.readOnly || control.compound) return "value"
  if (control.type === "button" || control.writeOnly) return "action"
  if (isToggle(control)) return "toggle"
  if (control.type === "menu" || control.type === "intmenu") return "menu"
  if (control.type === "int" && isFinite(Number(control.minimum)) && isFinite(Number(control.maximum))) return "slider"
  if (canEditRaw(control)) return "rawEdit"
  return "value"
}

function withValue(controls, name, value) {
  var updated = []
  for (var i = 0; i < controls.length; i++) {
    var source = controls[i]
    if (source.name !== name) {
      updated.push(source)
      continue
    }
    var copy = {}
    for (var key in source) copy[key] = source[key]
    copy.value = typedValue(String(value), source.type)
    copy.rawValue = String(value)
    copy.hasValue = true
    updated.push(copy)
  }
  return updated
}

function control(controls, name) {
  for (var i = 0; i < controls.length; i++) {
    if (controls[i].name === name) return controls[i]
  }
  return null
}

function optionLabel(control, fallback) {
  if (!control) return fallback
  for (var i = 0; i < control.options.length; i++) {
    if (String(control.options[i].value) === String(control.value)) return control.options[i].label
  }
  return fallback
}

function valueLabel(control, value) {
  if (!control) return ""
  if (control.writeOnly || !control.hasValue) return "Not reported"
  var current = value === undefined ? control.value : value
  var numeric = Number(current)
  if ((control.name === "exposure_time_absolute" || control.name === "exposure_absolute") && isFinite(numeric))
    return (numeric / 10).toFixed(numeric % 10 === 0 ? 0 : 1) + " ms"
  if (control.name === "white_balance_temperature" && isFinite(numeric)) return Math.round(numeric) + " K"
  if ((control.name === "pan_absolute" || control.name === "tilt_absolute") && isFinite(numeric))
    return (numeric / 3600).toFixed(1).replace(/\.0$/, "") + " deg"
  if ((control.type === "menu" || control.type === "intmenu")) return optionLabel(control, String(current))
  if (control.type === "bool") return Number(current) === 0 ? "Off" : "On"
  return String(current)
}

function limitationLabel(control) {
  if (!control) return ""
  if (control.compound) return "Complex V4L2 payload; displayed read-only."
  if (control.readOnly) return "Reported read-only by the device."
  if (control.inactive) return "Currently inactive because of another camera setting."
  if (control.grabbed) return "Temporarily grabbed by the device or another client."
  if (renderKind(control) === "value" && !control.readOnly) return "This control type is not safe to edit generically."
  return ""
}

function deviceOptions(devices, includeAutomatic) {
  var result = includeAutomatic ? [{ value: "", label: "Automatic · first capture device" }] : []
  for (var i = 0; i < devices.length; i++) {
    result.push({
      value: devices[i].device,
      label: safeOptionLabel(devices[i].name) + " · " + devices[i].device
    })
  }
  return result
}
