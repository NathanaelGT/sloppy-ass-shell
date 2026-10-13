import QtQuick
import "../theme"

Item {
  id: root

  property string text: ""
  property string shownText: ""
  property bool morphing: false
  property string fontFamily: Theme.fontFamily
  property int fontPixelSize: Theme.fontSizeSmall
  property color textColor: Theme.subtext
  property int rollMs: 160
  property int staggerMs: 20
  property var slots: []
  property string pending: ""

  readonly property int lineH: Math.max(1, Math.round(measurer.implicitHeight))
  readonly property int contentWidth: morphing ? slotRow.width : settled.implicitWidth
  property alias settledItem: settled

  implicitWidth: contentWidth
  implicitHeight: lineH

  function finishInstant() {
    finishTimer.stop()
    if (root.morphing) {
      root.shownText = root.pending
      root.morphing = false
    }
  }

  function setInstant(s) {
    root.text = s
    root.finishInstant()
    root.shownText = s
    root.slots = []
  }

  function morphTo(s) {
    root.text = s
    root.finishInstant()
    if (s === root.shownText) {
      return
    }
    root.pending = s
    const from = root.shownText
    const count = Math.max(from.length, s.length)
    const next = []
    for (let i = 0; i < count; i++) {
      next.push({
        o: from[i] || "",
        n: s[i] || ""
      })
    }
    root.morphing = true
    root.slots = next
    finishTimer.interval = root.rollMs + count * root.staggerMs + 60
    finishTimer.restart()
  }

  Timer {
    id: finishTimer

    onTriggered: {
      const target = root.text
      root.shownText = root.pending
      root.morphing = false
      if (target !== root.pending) {
        root.morphTo(target)
      }
    }
  }

  Text {
    id: measurer

    opacity: 0
    width: 0
    text: "Ag"
    font.family: root.fontFamily
    font.pixelSize: root.fontPixelSize
  }

  Text {
    id: settled

    visible: !root.morphing
    anchors.centerIn: parent
    text: root.shownText
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: root.fontPixelSize
  }

  Row {
    id: slotRow

    visible: root.morphing
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Repeater {
      model: root.slots

      delegate: Item {
        required property var modelData
        required property int index

        width: incomingLabel.implicitWidth
        height: root.lineH
        clip: true

        Component.onCompleted: if (root.morphing) {
          seq.restart()
        }

        SequentialAnimation {
          id: seq

          PauseAnimation {
            duration: index * root.staggerMs
          }
          NumberAnimation {
            target: pairBox
            property: "y"
            to: -root.lineH
            duration: root.rollMs
            easing.type: Easing.OutCubic
          }
        }

        Item {
          id: pairBox

          width: parent.width
          height: root.lineH * 2

          Text {
            width: parent.width
            height: root.lineH
            text: modelData.o
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontPixelSize
            elide: Text.ElideNone
            clip: true
          }

          Text {
            id: incomingLabel

            y: root.lineH
            width: parent.width
            height: root.lineH
            text: modelData.n
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontPixelSize
            elide: Text.ElideNone
            clip: true
          }
        }
      }
    }
  }
}
