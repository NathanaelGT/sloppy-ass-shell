import QtQuick
import "../theme"

Text {
  property string label: ""

  text: label
  color: Theme.subtext
  font.family: Theme.fontFamily
  font.pixelSize: Theme.fontSizeSmall
  font.bold: true
}
