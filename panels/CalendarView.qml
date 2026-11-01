import QtQuick
import "../theme"
import "../components"

Column {
  id: root

  property date cursor: new Date()
  property date previousCursor: cursor
  property var previousWeeks: []

  spacing: Math.round(6 * Theme.scale)

  readonly property date today: new Date()
  readonly property int cellSize: Math.round(30 * Theme.scale)
  readonly property int gridSpacing: Math.round(4 * Theme.scale)
  readonly property int contentWidth: cellSize * 8 + gridSpacing * 7

  readonly property var dayNames: {
    const names = []
    for (let i = 1; i <= 7; i++) {
      names.push(Theme.locale.dayName(i, Locale.ShortFormat))
    }
    return names
  }

  readonly property var weeks: {
    const first = new Date(root.cursor.getFullYear(), root.cursor.getMonth(), 1)
    const offset = (first.getDay() + 6) % 7
    const start = new Date(first.getFullYear(), root.cursor.getMonth(), 1 - offset)
    const result = []
    for (let w = 0; w < 6; w++) {
      const row = []
      for (let i = 0; i < 7; i++) {
        row.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7 + i))
      }
      result.push(row)
    }
    return result
  }

  function isoWeek(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    const day = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - day)
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  function step(delta) {
    root.previousCursor = root.cursor
    root.previousWeeks = root.weeks
    root.cursor = new Date(root.cursor.getFullYear(), root.cursor.getMonth() + delta, 1)
    currentStrip.y = delta > 0 ? numbersClip.height : -numbersClip.height
    previousStrip.y = 0
    slideAnim.to = 0
    prevSlideAnim.to = delta > 0 ? -numbersClip.height : numbersClip.height
    prevSlideAnim.restart()
    slideAnim.restart()
  }

  Row {
    width: parent.width
    spacing: root.gridSpacing

    BarButton {
      implicitWidth: Math.round(26 * Theme.scale)
      implicitHeight: Math.round(26 * Theme.scale)
      onClicked: root.step(-1)
      Icon {
        anchors.centerIn: parent
        name: "chevron-left"
        font.pixelSize: Theme.fontSize
      }
    }

    Text {
      width: parent.width - Math.round(64 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      text: root.cursor.toLocaleString(Theme.locale, "MMMM yyyy")
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeLarge
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }

    BarButton {
      implicitWidth: Math.round(26 * Theme.scale)
      implicitHeight: Math.round(26 * Theme.scale)
      onClicked: root.step(1)
      Icon {
        anchors.centerIn: parent
        name: "chevron-right"
        font.pixelSize: Theme.fontSize
      }
    }
  }

  Column {
    spacing: root.gridSpacing

    Row {
      spacing: root.gridSpacing

      Text {
        width: root.cellSize
        height: Math.round(18 * Theme.scale)
        text: "wk"
        color: Theme.overlay
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      Row {
        spacing: root.gridSpacing
        Repeater {
          model: root.dayNames
          delegate: Text {
            required property var modelData
            width: root.cellSize
            height: Math.round(18 * Theme.scale)
            text: modelData
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }
      }
    }

    Item {
      id: numbersClip

      width: currentStrip.implicitWidth
      height: currentStrip.implicitHeight
      clip: true

      Row {
        id: previousStrip

        property date refDate: root.previousCursor

        visible: root.previousWeeks.length > 0
        spacing: root.gridSpacing

        Column {
          spacing: root.gridSpacing
          Repeater {
            model: root.previousWeeks
            delegate: Text {
              required property var modelData
              width: root.cellSize
              height: root.cellSize
              text: root.isoWeek(modelData[0])
              color: Theme.overlay
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        Column {
          spacing: root.gridSpacing
          Repeater {
            model: root.previousWeeks
            delegate: Row {
              required property var modelData
              spacing: root.gridSpacing

              Repeater {
                model: modelData
                delegate: Rectangle {
                  required property var modelData
                  width: root.cellSize
                  height: root.cellSize
                  radius: Math.round(8 * Theme.scale)
                  color: root.sameDay(modelData, root.today) ? Theme.primary : (modelData.getMonth() === previousStrip.refDate.getMonth() ? Theme.surface : "transparent")

                  Text {
                    anchors.centerIn: parent
                    text: modelData.getDate()
                    color: root.sameDay(modelData, root.today) ? Theme.onAccent : (modelData.getMonth() === previousStrip.refDate.getMonth() ? Theme.text : Theme.overlay)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: root.sameDay(modelData, root.today)
                  }
                }
              }
            }
          }
        }
      }

      Row {
        id: currentStrip

        property date refDate: root.cursor

        spacing: root.gridSpacing

        Column {
          spacing: root.gridSpacing
          Repeater {
            model: root.weeks
            delegate: Text {
              required property var modelData
              width: root.cellSize
              height: root.cellSize
              text: root.isoWeek(modelData[0])
              color: Theme.overlay
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        Column {
          spacing: root.gridSpacing
          Repeater {
            model: root.weeks
            delegate: Row {
              required property var modelData
              spacing: root.gridSpacing

              Repeater {
                model: modelData
                delegate: Rectangle {
                  required property var modelData
                  width: root.cellSize
                  height: root.cellSize
                  radius: Math.round(8 * Theme.scale)
                  color: root.sameDay(modelData, root.today) ? Theme.primary : (modelData.getMonth() === currentStrip.refDate.getMonth() ? Theme.surface : "transparent")

                  Text {
                    anchors.centerIn: parent
                    text: modelData.getDate()
                    color: root.sameDay(modelData, root.today) ? Theme.onAccent : (modelData.getMonth() === currentStrip.refDate.getMonth() ? Theme.text : Theme.overlay)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: root.sameDay(modelData, root.today)
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  NumberAnimation {
    id: slideAnim

    target: currentStrip
    property: "y"
    duration: 200
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: prevSlideAnim

    target: previousStrip
    property: "y"
    duration: 200
    easing.type: Easing.OutCubic
  }
}
