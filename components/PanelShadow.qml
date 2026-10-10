import QtQuick
import QtQuick.Effects
import "../theme"

MultiEffect {
  id: root

  property Item shadowSource: null

  source: shadowSource
  x: shadowSource ? shadowSource.x : 0
  y: shadowSource ? shadowSource.y : 0
  width: shadowSource ? shadowSource.width : 0
  height: shadowSource ? shadowSource.height : 0
  shadowEnabled: true
  shadowColor: Theme.shadowColor
  shadowBlur: Theme.shadowBlur
  shadowOpacity: Theme.shadowOpacity
  shadowVerticalOffset: Theme.shadowVerticalOffset
  shadowHorizontalOffset: 0
}
