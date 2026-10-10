import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "control-center"
  align: "center"
  topMargin: Theme.barThickness + Math.round(6 * Theme.scale)
  cardWidth: Theme.controlCenterWidth

  Row {
    width: parent.width

    Text {
      width: parent.width - Math.round(30 * Theme.scale)
      text: new Date().toLocaleString(Theme.locale, "dddd, dd MMMM yyyy")
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeLarge
      font.bold: true
      elide: Text.ElideRight
    }

    BarButton {
      implicitWidth: Math.round(26 * Theme.scale)
      implicitHeight: Math.round(26 * Theme.scale)
      onClicked: Panels.close()
      Icon {
        anchors.centerIn: parent
        name: "x"
        font.pixelSize: Theme.fontSize
      }
    }
  }

  Grid {
    id: tiles

    columns: 2
    spacing: Theme.gap
    width: parent.width

    Tile {
      width: (tiles.width - Theme.gap) / 2
      icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
      label: "Wi-Fi"
      active: Networking.wifiEnabled
      onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    Tile {
      width: (tiles.width - Theme.gap) / 2
      icon: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "bluetooth" : "bluetooth-off"
      label: "Bluetooth"
      active: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
      onClicked: {
        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
      }
    }

    Tile {
      width: (tiles.width - Theme.gap) / 2
      icon: Notifs.dnd ? "bell-off" : "bell"
      label: "Silence"
      active: Notifs.dnd
      onClicked: Notifs.dnd = !Notifs.dnd
    }

    Tile {
      width: (tiles.width - Theme.gap) / 2
      icon: "power"
      label: "Session"
      active: false
      onClicked: Panels.open("session", screenId)
    }
  }

  Row {
    width: parent.width
    spacing: Theme.gap

    Icon {
      anchors.verticalCenter: parent.verticalCenter
      name: Audio.muted ? "volume-off" : "volume-2"
      font.pixelSize: Theme.iconSizeLarge
    }

    Slider {
      width: parent.width - Math.round(70 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      node: Audio.sink
      value: Audio.volume / Audio.maxVolume
      fullMark: 1 / Audio.maxVolume
      onMoved: (v) => Audio.setVolume(v * Audio.maxVolume)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(40 * Theme.scale)
      text: Math.round(Audio.volume * 100) + "%"
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      horizontalAlignment: Text.AlignRight
    }
  }

  Rectangle {
    visible: Media.active !== null
    width: parent.width
    height: visible ? Math.round(72 * Theme.scale) : 0
    radius: Math.round(14 * Theme.scale)
    color: Theme.surface

    Row {
      anchors.fill: parent
      anchors.margins: Math.round(10 * Theme.scale)
      spacing: Math.round(10 * Theme.scale)

      Image {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(52 * Theme.scale)
        height: width
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
        visible: Media.active && Media.active.trackArtUrl !== ""
        source: Media.active ? Media.active.trackArtUrl : ""
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Math.round(150 * Theme.scale)
        spacing: Math.round(2 * Theme.scale)

        Text {
          width: parent.width
          text: Media.active ? Media.active.trackTitle : ""
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: Media.active ? Media.active.trackArtist : ""
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
          elide: Text.ElideRight
        }
      }

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(2 * Theme.scale)

        BarButton {
          implicitWidth: Math.round(28 * Theme.scale)
          implicitHeight: Math.round(28 * Theme.scale)
          onClicked: if (Media.active) Media.active.previous()
          Icon {
            anchors.centerIn: parent
            name: "player-skip-back"
            font.pixelSize: Theme.fontSize
          }
        }

        BarButton {
          implicitWidth: Math.round(28 * Theme.scale)
          implicitHeight: Math.round(28 * Theme.scale)
          onClicked: if (Media.active) Media.active.togglePlaying()
          Icon {
            anchors.centerIn: parent
            name: Media.active && Media.active.isPlaying ? "player-pause" : "player-play"
            font.pixelSize: Theme.fontSize
          }
        }

        BarButton {
          implicitWidth: Math.round(28 * Theme.scale)
          implicitHeight: Math.round(28 * Theme.scale)
          onClicked: if (Media.active) Media.active.next()
          Icon {
            anchors.centerIn: parent
            name: "player-skip-forward"
            font.pixelSize: Theme.fontSize
          }
        }
      }
    }
  }

  CalendarView {
    id: calendar
    width: parent.width
  }

  Text {
    visible: {
      const list = Notifs.active;
      return list !== null && list !== undefined && typeof list.length === "number" && list.length > 0;
    }
    text: "Notifications"
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall
    font.bold: true
  }

  Column {
    id: toasts

    width: parent.width
    spacing: Math.round(6 * Theme.scale)

    Repeater {
      model: Notifs.active

      delegate: Rectangle {
        id: toast

        required property var modelData

        width: toasts.width
        height: Math.max(Math.round(52 * Theme.scale), bodyText.implicitHeight + Math.round(30 * Theme.scale))
        radius: Math.round(12 * Theme.scale)
        color: Theme.surface

        Row {
          anchors.fill: parent
          anchors.margins: Math.round(10 * Theme.scale)
          spacing: Math.round(10 * Theme.scale)

          Image {
            anchors.top: parent.top
            width: Math.round(22 * Theme.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: Quickshell.iconPath(toast.modelData.appIcon, "dialog-information")
          }

          Column {
            width: parent.width - Math.round(50 * Theme.scale)
            spacing: Math.round(2 * Theme.scale)

            Text {
              width: parent.width
              text: toast.modelData.summary
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: bodyText
              width: parent.width
              text: toast.modelData.body
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              wrapMode: Text.WordWrap
              maximumLineCount: 3
              elide: Text.ElideRight
            }
          }

          BarButton {
            implicitWidth: Math.round(24 * Theme.scale)
            implicitHeight: Math.round(24 * Theme.scale)
            onClicked: toast.modelData.dismiss()
            Icon {
              anchors.centerIn: parent
              name: "x"
              font.pixelSize: Theme.fontSizeSmall
            }
          }
        }
      }
    }
  }
}
