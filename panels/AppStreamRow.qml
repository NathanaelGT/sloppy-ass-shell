import QtQuick
import "../theme"
import "../components"

Column {
  id: root

  property var node: null
  property string kind: "output"
  property string label: ""
  property string target: "Default"
  property bool pinned: false
  property bool pinVisible: true
  property bool open: false
  property bool active: true
  property real maxVolume: 1.5

  signal pinToggled
  signal routePressed(var anchor)
  signal wheeled(real angleDelta)
  signal percentEditing(var editor)

  readonly property var audio: node ? node.audio : null
  readonly property var percentEditor: percentInput

  width: parent ? parent.width : 0
  spacing: Math.round(2 * Theme.scale)
  opacity: root.active ? 1 : 0.5
  layer.enabled: !root.active

  Item {
    width: parent.width
    height: Math.max(Math.round(20 * Theme.scale), Math.ceil(nameText.implicitHeight))

    Text {
      id: nameText

      anchors.left: parent.left
      anchors.right: controls.left
      anchors.rightMargin: Math.round(6 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.active ? Theme.subtext : Theme.overlay
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
    }

    Row {
      id: controls

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Math.round(4 * Theme.scale)

      IconButton {
        anchors.verticalCenter: parent.verticalCenter
        size: Math.round(20 * Theme.scale)
        name: root.pinned ? "pin-filled" : "pin"
        iconColor: root.pinned ? Theme.primary : Theme.overlay
        opacity: root.pinVisible ? 1 : 0
        enabled: root.pinVisible
        onClicked: root.pinToggled()

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }
      }

      Rectangle {
        id: routeChip

        anchors.verticalCenter: parent.verticalCenter
        readonly property real chipMax: Math.round(160 * Theme.scale)
        readonly property real padLeft: Math.round(6 * Theme.scale)
        readonly property real padRight: Math.round(4 * Theme.scale)
        readonly property real gap: Math.round(2 * Theme.scale)
        readonly property real chevronWidth: Math.round(14 * Theme.scale)
        readonly property real chrome: padLeft + gap + chevronWidth + padRight
        readonly property real labelWidth: Math.min(routeLabel.implicitWidth, chipMax - chrome)
        width: labelWidth + chrome
        height: Math.round(18 * Theme.scale)
        radius: Math.round(6 * Theme.scale)
        color: routeMouse.containsMouse || root.open ? Theme.surfaceHigher : Theme.surfaceHigh
        antialiasing: true

        Text {
          id: routeLabel

          anchors.left: parent.left
          anchors.leftMargin: routeChip.padLeft
          anchors.right: routeChevron.left
          anchors.rightMargin: routeChip.gap
          anchors.verticalCenter: parent.verticalCenter
          text: root.target
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Math.round(9 * Theme.scale)
          elide: Text.ElideRight
        }

        Icon {
          id: routeChevron

          anchors.right: parent.right
          anchors.rightMargin: routeChip.padRight
          anchors.verticalCenter: parent.verticalCenter
          width: routeChip.chevronWidth
          name: "chevron-down"
          font.pixelSize: Math.round(9 * Theme.scale)
        }

        MouseArea {
          id: routeMouse

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.routePressed(routeChip)
        }
      }
    }
  }

  Row {
    width: parent.width
    spacing: Math.round(6 * Theme.scale)

    Slider {
      width: parent.width - Math.round(64 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      node: root.node
      value: root.audio ? root.audio.volume / root.maxVolume : 0
      fullMark: 1 / root.maxVolume
      onMoved: v => {
        if (root.audio) {
          root.audio.volume = v * root.maxVolume
        }
      }
      onWheeled: angleDelta => root.wheeled(angleDelta)
    }

    EditablePercent {
      id: percentInput

      anchors.verticalCenter: parent.verticalCenter
      percent: root.audio ? root.audio.volume * 100 : 0
      maximum: root.maxVolume * 100
      onEdited: value => {
        if (root.audio) {
          root.audio.volume = value / 100
        }
      }
      onWheeled: angleDelta => root.wheeled(angleDelta)
      onEditingChanged: root.percentEditing(editing ? percentInput : null)
    }

    MuteButton {
      anchors.verticalCenter: parent.verticalCenter
      kind: root.kind
      muted: root.audio ? root.audio.muted : false
      level: root.audio ? root.audio.volume : 0
      maxLevel: root.maxVolume
      onClicked: {
        if (root.audio) {
          root.audio.muted = !root.audio.muted
        }
      }
      onWheeled: angleDelta => root.wheeled(angleDelta)
    }
  }
}
