import QtQuick
import "../theme"

Text {
  property string name: ""

  text: Icons.get(name)
  font.family: Theme.iconFamily
  font.pixelSize: Theme.iconSize
  color: Theme.text
  verticalAlignment: Text.AlignVCenter
  horizontalAlignment: Text.AlignHCenter
}
