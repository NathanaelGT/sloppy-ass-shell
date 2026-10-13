pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: root

  property bool visible: false
  property string icon: ""
  property string label: ""
  property real value: -1

  function show(iconName, text, amount) {
    icon = iconName
    label = text
    value = amount
    visible = true
    timer.restart()
  }

  Timer {
    id: timer
    interval: 2500
    onTriggered: root.visible = false
  }
}
