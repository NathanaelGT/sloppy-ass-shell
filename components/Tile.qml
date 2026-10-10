import QtQuick
import "../theme"

Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property bool active: false
  property color accent: Theme.primary

  signal clicked()
  signal rightClicked()

  implicitHeight: Math.round(58 * Theme.scale)
  radius: Math.round(15 * Theme.scale)
  color: active ? accent : Theme.surface
  antialiasing: true

  Behavior on color {
    ColorAnimation { duration: 150 }
  }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(4 * Theme.scale)

    Icon {
      anchors.horizontalCenter: parent.horizontalCenter
      name: root.icon
      color: root.active ? Theme.onAccent : Theme.text
      font.pixelSize: Theme.iconSizeLarge
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      color: root.active ? Theme.onAccent : Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (e) => e.button === Qt.LeftButton ? root.clicked() : root.rightClicked()
  }
}
