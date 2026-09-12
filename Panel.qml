import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.kristoferlund.webcam"
  ipcTarget: "io.github.kristoferlund.webcam"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string device: ""
  property string deviceName: "Webcam"
  property string targetDevice: ""
  property string stateRequestDevice: ""
  property var devices: []
  property var controls: []
  property bool loading: false
  property bool editing: false
  property bool menuOpen: false
  property bool refreshPending: false
  property string lastError: ""
  property string lastNotice: ""
  property var writeQueue: []
  property var activeWrite: null

  readonly property var barIdentity: hostWidget || root
  readonly property bool connected: device !== ""
  readonly property string configuredDevice: String(setting("device", "") || "").trim()
  readonly property var deviceChoices: Model.deviceOptions(devices, true)
  readonly property var controlGroups: Model.groupControls(controls)
  readonly property string helperPath: decodeURIComponent(
    String(Qt.resolvedUrl("webcamctl")).replace(/^file:\/\//, ""))
  readonly property color contentForeground: root.bar ? root.bar.foreground : Color.foreground
  readonly property string contentFontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // One MediaDevices for the whole panel: the preview needs the matched
  // CameraDevice, and so does anything that asks which formats it offers.
  MediaDevices { id: mediaDevices }

  readonly property var previewDevice: {
    var inputs = mediaDevices.videoInputs
    for (var i = 0; i < inputs.length; i++) {
      if (String(inputs[i].id) === root.device) return inputs[i]
    }
    return null
  }
  readonly property var previewFormats: root.previewDevice ? root.previewDevice.videoFormats : []
  readonly property string previewResolution: String(setting("resolution", "") || "").trim()
  readonly property var previewFormat: Model.pickFormat(root.previewFormats, root.previewResolution)
  readonly property var resolutionChoices: Model.resolutionOptions(root.previewFormats)

  function open() {
    root.refresh()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function selectResolution(value) {
    root.persistSettings({ resolution: String(value || "") })
  }

  function selectDevice(value) {
    var selected = String(value || "")
    if (selected !== "" && !/^\/dev\/video\d+$/.test(selected)) return
    root.targetDevice = selected
    root.device = ""
    root.deviceName = "Webcam"
    root.controls = []
    root.writeQueue = []
    root.lastError = ""
    root.lastNotice = ""
    root.persistSettings({ device: selected, resolution: "" })
    root.refreshState()
  }

  function refreshDevices() {
    if (devicesProc.running) return
    devicesProc.command = ["bash", root.helperPath, "devices"]
    devicesProc.running = true
  }

  function refresh() {
    root.refreshDevices()
    root.refreshState()
  }

  function refreshState() {
    if (stateProc.running) {
      root.refreshPending = true
      return
    }
    root.loading = true
    root.lastError = ""
    root.lastNotice = ""
    root.stateRequestDevice = root.targetDevice
    stateProc.command = ["bash", root.helperPath, "state", root.stateRequestDevice]
    stateProc.running = true
  }

  function applyState(text) {
    if (root.editing) return
    var state = Model.parseState(text)
    root.device = state.device
    root.deviceName = state.deviceName || state.device || "Webcam"
    root.controls = state.controls
    // Capture cards expose no controls at all -- that is the hardware being a
    // capture card, not a failure, so it must not read as an error.
    root.lastNotice = (root.connected && root.controls.length === 0)
      ? "This device reports no V4L2 controls, which is normal for a capture card. Preview and resolution still work."
      : ""
  }

  function updateValue(name, value) {
    root.controls = Model.withValue(root.controls, name, value)
  }

  function resetControl(control) {
    if (!Model.canReset(control)) return
    root.queueWrite(control.name, control.rawDefault, true)
  }

  function queueWrite(name, value, optimistic) {
    var writeValue = String(value)
    if (optimistic !== false) root.updateValue(name, writeValue)
    var nextQueue = []
    for (var i = 0; i < root.writeQueue.length; i++) {
      if (root.writeQueue[i].name !== name) nextQueue.push(root.writeQueue[i])
    }
    nextQueue.push({ name: name, value: writeValue })
    root.writeQueue = nextQueue
    root.startNextWrite()
  }

  function startNextWrite() {
    if (writeProc.running || root.writeQueue.length === 0 || root.device === "") return
    var nextQueue = root.writeQueue.slice(0)
    root.activeWrite = nextQueue.shift()
    root.writeQueue = nextQueue
    root.lastError = ""
    root.lastNotice = ""
    writeProc.command = [
      "bash", root.helperPath, "set", root.device,
      root.activeWrite.name, root.activeWrite.value
    ]
    writeProc.running = true
  }

  function finishWrite(exitCode, errorText) {
    if (exitCode !== 0) {
      var message = String(errorText || "").trim()
      root.lastError = message !== "" ? message : "Could not apply the webcam setting."
      root.refreshDevices()
    }
    root.activeWrite = null
    if (root.writeQueue.length > 0) root.startNextWrite()
    else refreshAfterWrite.restart()
  }

  Component.onCompleted: {
    root.targetDevice = root.configuredDevice
    root.refreshDevices()
    root.refreshState()
  }
  onConfiguredDeviceChanged: {
    if (root.targetDevice === root.configuredDevice) return
    root.targetDevice = root.configuredDevice
    root.refreshState()
  }

  Timer {
    id: refreshAfterWrite
    interval: 180
    repeat: false
    onTriggered: root.refreshState()
  }

  Process {
    id: devicesProc
    stdout: StdioCollector { id: devicesOutput; waitForEnd: true }
    stderr: StdioCollector { id: devicesError; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (!root || typeof root.applyState !== "function") return
        if (exitCode === 0) {
          var parsedDevices = Model.parseDevices(devicesOutput.text)
          if (!Model.deviceListsEqual(root.devices, parsedDevices)) root.devices = parsedDevices
        } else if (!root.connected) {
          var message = String(devicesError.text || "").trim()
          root.lastError = message !== "" ? message : "Could not enumerate video capture devices."
        }
      })
    }
  }

  Process {
    id: stateProc
    stdout: StdioCollector { id: stateOutput; waitForEnd: true }
    stderr: StdioCollector { id: stateError; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (!root || typeof root.applyState !== "function") return
        root.loading = false
        var stale = root.stateRequestDevice !== root.targetDevice
        if (!stale && exitCode === 0) {
          root.applyState(stateOutput.text)
        } else if (!stale) {
          root.device = ""
          root.deviceName = "Webcam"
          root.controls = []
          var message = String(stateError.text || "").trim()
          root.lastError = message !== "" ? message : "Could not read webcam controls."
          root.refreshDevices()
        }
        if (root.refreshPending) {
          root.refreshPending = false
          Qt.callLater(root.refreshState)
        }
      })
    }
  }

  Process {
    id: writeProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: writeError; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() { if (root && typeof root.finishWrite === "function") root.finishWrite(exitCode, writeError.text) })
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    readonly property real bodySpacing: Style.space(10)
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(
      fixedRegion.implicitHeight + panel.bodySpacing + controlsColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.menuOpen || root.editing
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: fixedRegion
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(9)

        BorderSurface {
          id: previewSurface
          visible: root.connected
          width: parent.width
          implicitHeight: width * 9 / 16
          radius: Style.cornerRadius
          clip: true
          color: Qt.rgba(root.contentForeground.r * 0.08, root.contentForeground.g * 0.08,
                         root.contentForeground.b * 0.08, 1)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)

          Loader {
            id: previewLoader
            anchors.fill: parent
            active: root.opened && root.connected
            sourceComponent: previewComponent
          }

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Style.space(8)
            width: previewBadge.implicitWidth + Style.space(12)
            height: previewBadge.implicitHeight + Style.space(6)
            radius: Style.cornerRadius
            color: Qt.rgba(0, 0, 0, 0.68)

            Text {
              id: previewBadge
              anchors.centerIn: parent
              text: "PREVIEW · " + (previewLoader.item ? previewLoader.item.stateLabel : "OFF")
              color: "white"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
              textFormat: Text.PlainText
            }
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, refreshButton.implicitHeight)

          Text {
            id: heroIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰄀"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
            opacity: root.connected ? 1.0 : 0.42
            textFormat: Text.PlainText
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: refreshButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              text: "Webcam Controls"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              text: root.loading ? "READING CAMERA SETTINGS"
                : (root.connected ? root.deviceName.toUpperCase() : "NO CAPTURE DEVICE")
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
          }

          PanelActionButton {
            id: refreshButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰑐"
            tooltipText: "Refresh devices and controls"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            enabled: !root.loading
            focusable: true
            onClicked: root.refresh()
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Text {
            text: "CAPTURE DEVICE"
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
            textFormat: Text.PlainText
          }

          Dropdown {
            width: parent.width
            showLabel: false
            value: root.targetDevice
            options: root.deviceChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onPopupOpenChanged: root.menuOpen = popupOpen
            onChanged: function(value) { root.selectDevice(value) }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.resolutionChoices.length > 1

          Text {
            text: "PREVIEW RESOLUTION"
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
            textFormat: Text.PlainText
          }

          Dropdown {
            width: parent.width
            showLabel: false
            value: root.previewResolution
            options: root.resolutionChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onPopupOpenChanged: root.menuOpen = popupOpen
            onChanged: function(value) { root.selectResolution(value) }
          }
        }
      }

      ScrollView {
        id: controlsScroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: fixedRegion.bottom
        anchors.topMargin: panel.bodySpacing
        anchors.bottom: parent.bottom
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: controlsColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Binding {
          target: controlsScroll.contentItem
          property: "interactive"
          value: controlsColumn.implicitHeight > controlsScroll.height
        }

        Column {
          id: controlsColumn
          // Keep transient scrollbars out of right-aligned values and reset targets.
          width: Math.max(1, controlsScroll.availableWidth - Style.space(14))
          spacing: Style.space(8)

          Text {
            visible: root.lastNotice !== "" && root.lastError === ""
            width: parent.width
            text: root.lastNotice
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            visible: root.lastError !== ""
            width: parent.width
            text: root.lastError
            color: root.bar ? root.bar.urgent : Color.urgent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            visible: !root.loading && !root.connected && root.lastError === ""
            width: parent.width
            text: "Connect a V4L2 video capture device, then refresh. Metadata-only video nodes are not listed."
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Repeater {
            model: root.controlGroups
            ControlSection {
              required property var modelData
              title: modelData.title
              controlsList: modelData.controls
            }
          }

          Item { width: parent.width; height: Style.space(2) }
        }
      }
    }
  }

  Component {
    id: previewComponent
    Item {
      id: previewHost
      property string cameraError: ""
      readonly property var matchedDevice: root.previewDevice

      // Qt drops cameraFormat both when cameraDevice changes and when the camera
      // is activated, so it cannot be bound -- it has to be re-applied after
      // each of those. Skipping a redundant assignment keeps activation from
      // chasing its own tail.
      function applyFormat() {
        var want = root.previewFormat
        if (!camera.cameraDevice || !want) return
        var current = camera.cameraFormat
        if (current && current.resolution.width === want.resolution.width
            && current.resolution.height === want.resolution.height) return
        camera.cameraFormat = want
      }

      Component.onCompleted: previewHost.applyFormat()
      readonly property string stateLabel: matchedDevice === null ? "UNAVAILABLE"
        : (camera.error !== Camera.NoError ? "IN USE / ERROR" : "LIVE")

      Camera {
        id: camera
        cameraDevice: previewHost.matchedDevice
        active: previewHost.matchedDevice !== null
        // Setting cameraDevice resets cameraFormat inside Qt, so the format has
        // to be re-applied afterwards rather than bound. A binding only re-fires
        // when its value differs, and leaving a device and returning to it can
        // yield an equal format -- the reset then stands, and the preview drops
        // back to the driver's first mode with the panel still showing the size
        // the user picked.
        onCameraDeviceChanged: previewHost.applyFormat()
        onActiveChanged: if (camera.active) previewHost.applyFormat()
        onErrorOccurred: function(error, errorString) { previewHost.cameraError = errorString }
      }

      // Re-apply when the choice changes but the device does not.
      Connections {
        target: root
        function onPreviewFormatChanged() { previewHost.applyFormat() }
      }
      CaptureSession { camera: camera; videoOutput: videoOutput }
      VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
      }
      Rectangle {
        anchors.fill: parent
        visible: previewHost.matchedDevice === null || camera.error !== Camera.NoError
        color: Qt.rgba(0, 0, 0, 0.72)
        Text {
          anchors.centerIn: parent
          width: parent.width - Style.space(40)
          text: previewHost.matchedDevice === null
            ? "Preview unavailable for " + root.device
            : (previewHost.cameraError || camera.errorString || "The camera may be in use by another application.")
          color: "white"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
        }
      }
    }
  }

  component ControlSection: Column {
    required property string title
    required property var controlsList
    width: parent ? parent.width : 0
    spacing: Style.space(7)

    PanelSeparator { width: parent.width; foreground: root.contentForeground }
    PanelSectionHeader { text: parent.title; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

    Repeater {
      model: parent.controlsList
      Loader {
        required property var modelData
        width: parent.width
        property var controlData: modelData
        sourceComponent: {
          var kind = Model.renderKind(controlData)
          if (kind === "toggle") return toggleControl
          if (kind === "menu") return menuControl
          if (kind === "slider") return sliderControl
          if (kind === "action") return actionControl
          if (kind === "rawEdit") return rawEditControl
          return valueControl
        }
      }
    }
  }

  component ControlLimitation: Text {
    required property var controlData
    width: parent ? parent.width : 0
    text: Model.limitationLabel(controlData)
    visible: text !== ""
    color: Qt.darker(root.contentForeground, 1.45)
    font.family: root.contentFontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
  }

  Component {
    id: sliderControl
    Column {
      readonly property var controlData: parent.controlData
      width: parent.width
      spacing: Style.space(4)
      opacity: Model.isBlocked(controlData) ? 0.42 : 1.0
      enabled: !Model.isBlocked(controlData)
      Item {
        width: parent.width
        implicitHeight: Math.max(controlLabel.implicitHeight, controlValue.implicitHeight)
        Text {
          id: controlLabel
          anchors.left: parent.left
          text: controlData.label
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          textFormat: Text.PlainText
        }
        Text {
          id: controlValue
          anchors.right: parent.right
          text: Model.valueLabel(controlData, controlSlider.dragging
            ? Model.snapValue(controlData, controlSlider.liveValue)
            : controlData.value)
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          textFormat: Text.PlainText

          MouseArea {
            id: resetValueArea
            anchors.fill: parent
            enabled: Model.canReset(controlData)
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onDoubleClicked: root.resetControl(controlData)
          }

          PanelToolTip {
            visible: resetValueArea.containsMouse
            text: "Double-click to reset to " + Model.valueLabel(controlData, controlData.defaultValue)
            fontFamily: root.contentFontFamily
          }
        }
      }
      PanelSlider {
        id: controlSlider
        width: parent.width
        bar: root.bar
        minimum: Number(controlData.minimum)
        maximum: Number(controlData.maximum)
        step: Math.max(1, Number(controlData.step) || 1)
        value: Number(controlData.value)
        integer: true
        onMoved: root.editing = true
        onReleased: function(value) {
          root.editing = false
          root.queueWrite(controlData.name, Model.snapValue(controlData, value), true)
        }
      }
      ControlLimitation { controlData: parent.controlData }
    }
  }

  Component {
    id: menuControl
    Column {
      readonly property var controlData: parent.controlData
      width: parent.width
      spacing: Style.space(4)
      opacity: Model.isBlocked(controlData) ? 0.42 : 1.0
      enabled: !Model.isBlocked(controlData)
      Text { width: parent.width; text: controlData.label; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; textFormat: Text.PlainText }
      Dropdown {
        width: parent.width
        showLabel: false
        value: String(controlData.value)
        options: controlData.options
        foreground: root.contentForeground
        fontFamily: root.contentFontFamily
        onPopupOpenChanged: root.menuOpen = popupOpen
        onChanged: function(value) { root.queueWrite(controlData.name, value, true) }
      }
      ControlLimitation { controlData: parent.controlData }
    }
  }

  Component {
    id: toggleControl
    Column {
      readonly property var controlData: parent.controlData
      width: parent.width
      spacing: Style.space(3)
      opacity: Model.isBlocked(controlData) ? 0.42 : 1.0
      enabled: !Model.isBlocked(controlData)
      Toggle {
        width: parent.width
        label: parent.controlData.label
        checked: Number(parent.controlData.value) === 1
        foreground: root.contentForeground
        fontFamily: root.contentFontFamily
        onClicked: root.queueWrite(parent.controlData.name, checked ? 0 : 1, true)
      }
      ControlLimitation { controlData: parent.controlData }
    }
  }

  Component {
    id: actionControl
    Column {
      readonly property var controlData: parent.controlData
      width: parent.width
      spacing: Style.space(4)
      opacity: Model.isBlocked(controlData) ? 0.42 : 1.0
      enabled: !Model.isBlocked(controlData)
      Item {
        width: parent.width
        implicitHeight: Math.max(actionLabel.implicitHeight, actionButton.implicitHeight)
        Text {
          id: actionLabel
          anchors.left: parent.left
          anchors.right: actionButton.left
          anchors.verticalCenter: parent.verticalCenter
          text: controlData.label
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        Button {
          id: actionButton
          anchors.right: parent.right
          text: "Run"
          bordered: true
          focusable: true
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.queueWrite(controlData.name, "1", false)
        }
      }
      ControlLimitation { controlData: parent.controlData }
    }
  }

  Component {
    id: rawEditControl
    Column {
      readonly property var controlData: parent.controlData
      width: parent.width
      spacing: Style.space(4)
      opacity: Model.isBlocked(controlData) ? 0.42 : 1.0
      enabled: !Model.isBlocked(controlData)
      Text { width: parent.width; text: controlData.label + " · " + Model.valueLabel(controlData); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; textFormat: Text.PlainText }
      Row {
        width: parent.width
        spacing: Style.space(6)
        TextField {
          id: rawField
          width: parent.width - applyButton.width - parent.spacing
          text: controlData.hasValue ? String(controlData.value) : ""
          placeholderText: controlData.type === "string" ? "String value" : "Decimal or hexadecimal value"
          foreground: root.contentForeground
          font.family: root.contentFontFamily
          onActiveFocusChanged: root.editing = activeFocus
          onAccepted: applyButton.clicked()
        }
        Button {
          id: applyButton
          text: "Apply"
          bordered: true
          focusable: true
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: {
            root.editing = false
            root.queueWrite(controlData.name, rawField.text, true)
          }
        }
      }
      ControlLimitation { controlData: parent.controlData }
    }
  }

  Component {
    id: valueControl
    Column {
      readonly property var controlData: parent.controlData
      width: parent.width
      spacing: Style.space(3)
      opacity: controlData.inactive || controlData.grabbed ? 0.55 : 1.0
      Item {
        width: parent.width
        implicitHeight: Math.max(valueName.implicitHeight, rawValue.implicitHeight)
        Text {
          id: valueName
          anchors.left: parent.left
          anchors.right: rawValue.left
          text: controlData.label
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        Text {
          id: rawValue
          anchors.right: parent.right
          text: Model.valueLabel(controlData)
          color: Qt.darker(root.contentForeground, 1.35)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          textFormat: Text.PlainText
        }
      }
      ControlLimitation { controlData: parent.controlData }
    }
  }
}
