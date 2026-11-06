import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

WlSessionLockSurface {
  id: root

  color: Theme.base

  LockBackground {
    anchors.fill: parent
    screenName: root.screen ? root.screen.name : ""
  }

  LockScreen {
    anchors.fill: parent
    screenName: root.screen ? root.screen.name : ""
    preview: false
  }
}
