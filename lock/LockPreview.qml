import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
  id: root

  required property var modelData

  readonly property string screenId: modelData ? modelData.name : ""
  readonly property bool open: root.visible

  function testRect() {
    return {
      x: 0,
      y: 0,
      width: root.width,
      height: root.height
    }
  }

  screen: modelData
  color: "transparent"
  WlrLayershell.namespace: "quickshell-lock"
  visible: LockState.previewActive && root.screenId === "eDP-1"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  aboveWindows: true
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  onVisibleChanged: {
    if (root.visible) {
      TestDriver.register("lock", root.screenId, root)
    } else {
      TestDriver.unregister("lock", root.screenId)
    }
  }

  LockBackground {
    anchors.fill: parent
    visible: root.visible
  }

  LockScreen {
    anchors.fill: parent
    screenName: root.screenId
    preview: true
    shown: root.visible
  }
}
