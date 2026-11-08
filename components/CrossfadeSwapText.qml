import QtQuick

Item {
  id: root

  property string want: ""
  property string shown: want
  property font font
  property color color: "#000000"

  implicitWidth: Math.max(older.implicitWidth, newer.implicitWidth)
  implicitHeight: Math.max(older.implicitHeight, newer.implicitHeight)
  width: implicitWidth
  height: implicitHeight

  onWantChanged: {
    if (want === shown) {
      swap.stop()
      return
    }
    older.text = shown
    older.opacity = 1
    shown = want
    newer.opacity = 0
    swap.restart()
  }

  Component.onCompleted: {
    swap.stop()
    shown = want
    older.text = ""
    older.opacity = 0
    newer.opacity = 1
  }

  Text {
    id: newer

    anchors.centerIn: parent
    font: root.font
    color: root.color
    text: root.shown
    opacity: 1
  }

  Text {
    id: older

    anchors.centerIn: parent
    font: root.font
    color: root.color
    text: ""
    opacity: 0
  }

  ParallelAnimation {
    id: swap

    NumberAnimation {
      target: newer
      property: "opacity"
      to: 1
      duration: 140
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: older
      property: "opacity"
      to: 0
      duration: 140
      easing.type: Easing.OutCubic
    }
  }
}
