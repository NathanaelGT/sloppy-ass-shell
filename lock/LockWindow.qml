import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow {
  id: root

  required property var modelData

  readonly property string screenId: modelData ? modelData.name : ""
  readonly property bool shown: LockState.sessionLocked
  property bool fadeVisible: false

  onShownChanged: {
    if (root.shown) {
      fadeOutAnim.stop()
      root.fadeVisible = true
      content.opacity = 0
      fadeInAnim.restart()
    } else {
      fadeInAnim.stop()
      fadeOutAnim.restart()
    }
  }

  screen: modelData
  color: "transparent"
  visible: root.fadeVisible
  WlrLayershell.namespace: "quickshell-lock"

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
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Item {
    id: content

    anchors.fill: parent
    opacity: 0

    LockBackground {
      anchors.fill: parent
      visible: root.fadeVisible
    }

    LockScreen {
      anchors.fill: parent
      screenName: root.screenId
      preview: false
      shown: root.fadeVisible
    }
  }

  NumberAnimation {
    id: fadeInAnim

    target: content
    property: "opacity"
    to: 1
    duration: 500
    easing.type: Easing.OutSine
  }

  NumberAnimation {
    id: fadeOutAnim

    target: content
    property: "opacity"
    to: 0
    duration: 500
    easing.type: Easing.InSine

    onFinished: {
      if (!root.shown) {
        root.fadeVisible = false
        content.opacity = 0
      }
    }
  }
}
