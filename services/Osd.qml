pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: root

  property bool visible: false
  property string pinScreen: ""
  property bool pinHeld: false
  property string icon: ""
  property string label: ""
  property real value: -1
  property bool volumeIcon: false

  function show(iconName, text, amount, usesVolumeIcon) {
    icon = iconName
    label = text
    value = amount
    volumeIcon = usesVolumeIcon === true
    if (!pinHeld || !screenAlive(pinScreen)) {
      pinScreen = Hypr.focusedScreenName
      pinHeld = true
    }
    visible = true
    timer.restart()
  }

  function releasePin(screenId) {
    if (screenId !== pinScreen) {
      return
    }
    pinScreen = ""
    pinHeld = false
  }

  function screenAlive(name) {
    const screens = Quickshell.screens
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name === name) {
        return true
      }
    }
    return false
  }

  Timer {
    id: timer

    interval: 2500
    onTriggered: root.visible = false
  }
}
