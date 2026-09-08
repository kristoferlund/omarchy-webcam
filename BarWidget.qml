import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.kristoferlund.webcam"

  // Optional outer widget used for bar popout ownership.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool connected: panelLoader.item
    ? panelLoader.item.connected === true
    : false
  readonly property bool poweredOff: panelLoader.item
    ? panelLoader.item.poweredOff === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function refresh() {
    if (panelLoader.item) panelLoader.item.refresh()
  }

  function togglePower() {
    if (panelLoader.item) panelLoader.item.togglePower()
  }

  function setPower(on) {
    if (panelLoader.item) panelLoader.item.setPower(on)
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root.barIdentity
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.kristoferlund.webcam"

    function refresh() { root.broadcast("refresh") }
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function powerOn() { root.setPower(true) }
    function powerOff() { root.setPower(false) }
    function togglePower() { root.togglePower() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.poweredOff ? "󰗟" : "󰄀"
    opacity: root.connected || root.poweredOff ? 1.0 : 0.48
    tooltipText: root.poweredOff
      ? "Webcam powered off · right-click to power on"
      : (root.connected
        ? "Webcam controls · right-click to power off"
        : "No webcam capture device detected")

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else if (buttonCode === Qt.RightButton) root.togglePower()
      else root.toggle()
    }
  }
}
