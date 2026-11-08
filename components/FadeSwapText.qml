import QtQuick

Text {
  id: root

  property string want: ""
  property string shown: want

  onWantChanged: {
    if (want === shown) {
      swap.stop()
      root.opacity = 1
    } else {
      swap.restart()
    }
  }

  Component.onCompleted: {
    swap.stop()
    opacity = 1
  }

  text: shown

  SequentialAnimation {
    id: swap

    NumberAnimation {
      target: root
      property: "opacity"
      to: 0
      duration: 90
      easing.type: Easing.OutCubic
    }

    ScriptAction {
      script: root.shown = root.want
    }

    NumberAnimation {
      target: root
      property: "opacity"
      to: 1
      duration: 90
      easing.type: Easing.OutCubic
    }
  }
}
