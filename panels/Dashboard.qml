import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Io
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "dashboard"
  align: "center"
  topMargin: Theme.barThickness + Math.round(6 * Theme.scale)
  cardWidth: Theme.dashboardWidth
  popupOpen: playerPopup.opened
  cancelItem: root.activeEditor
  onCancelRequested: {
    if (root.activeEditor) {
      root.activeEditor.cancel()
    }
  }

  property var picked: null
  property var activeEditor: null
  property bool seeking: false
  property real seekPreview: 0
  property real routeDismissedAt: 0
  property real localPosition: 0

  readonly property var players: Media.players
  readonly property bool pickedValid: picked !== null && players.indexOf(picked) !== -1
  readonly property var target: pickedValid ? picked : Media.active
  readonly property bool multiPlayer: players.length > 1
  readonly property real seekFraction: root.target && root.target.length > 0 ? Math.max(0, Math.min(1, root.localPosition / root.target.length)) : 0

  onTargetChanged: root.syncPosition()

  function syncPosition() {
    if (root.target) {
      root.localPosition = root.target.position
    } else {
      root.localPosition = 0
    }
  }

  function s(n) {
    return Math.round(n * Theme.scale)
  }

  function hairline() {
    return Math.max(1, Math.round(Theme.scale))
  }

  function fmtTime(seconds) {
    const total = Math.max(0, Math.floor(seconds))
    const h = Math.floor(total / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = total % 60
    const ss = String(s).padStart(2, "0")
    if (h > 0) {
      return h + ":" + String(m).padStart(2, "0") + ":" + ss
    }
    return m + ":" + ss
  }

  function cycle(delta) {
    const list = root.players
    if (list.length < 2) {
      return
    }
    const current = root.target ? list.indexOf(root.target) : -1
    root.picked = list[(current + delta + list.length) % list.length]
  }

  function resetPick() {
    root.picked = null
  }

  function previewSeek(fraction) {
    if (!root.target || root.target.length <= 0 || !root.target.canSeek) {
      return
    }
    root.seeking = true
    root.seekPreview = Math.max(0, Math.min(1, fraction))
    seekCommitTimer.restart()
  }

  function commitSeek() {
    if (!root.seeking) {
      return
    }
    root.seeking = false
    if (root.target && root.target.length > 0) {
      root.target.position = root.seekPreview * root.target.length
      root.localPosition = root.target.position
    }
  }

  function wheelSeek(delta) {
    if (!root.target || !root.target.positionSupported || !root.target.canSeek) {
      return
    }
    root.target.position = Math.max(0, root.target.position + (delta > 0 ? 1 : -1) * 5)
    root.localPosition = Math.max(0, root.localPosition + (delta > 0 ? 1 : -1) * 5)
  }

  function openPopupAt(popup, anchor) {
    if (popup.opened) {
      popup.close()
      return
    }
    if (Date.now() - root.routeDismissedAt < 250) {
      return
    }
    root.routeDismissedAt = 0
    const offset = Math.round(4 * Theme.scale)
    const reference = popup.parent
    const anchorX = anchor.width - popup.width
    const anchorY = anchor.height + offset
    const point = reference ? anchor.mapToItem(reference, anchorX, anchorY) : anchor.mapToItem(null, anchorX, anchorY)
    popup.x = point.x
    popup.y = point.y
    popup.open()
  }

  function closePopup(popup) {
    root.routeDismissedAt = popup.opened ? Date.now() : 0
    popup.close()
  }

  function testDashState() {
    const rows = []
    for (let i = 0; i < root.players.length; i++) {
      rows.push({
        identity: root.players[i].identity,
        playing: root.players[i].isPlaying
      })
    }
    return JSON.stringify({
      players: rows,
      pick: root.pickedValid ? root.players.indexOf(root.picked) : -1,
      target: root.target ? root.target.identity : null,
      playing: root.target ? root.target.isPlaying : false,
      position: root.localPosition
    })
  }

  function testDashPick(index) {
    if (index < 0 || index >= root.players.length) {
      return false
    }
    root.picked = root.players[index]
    return true
  }

  function testDashPlayerOpen() {
    root.routeDismissedAt = 0
    root.openPopupAt(playerPopup, playerBtn)
    return playerPopup.opened
  }

  function testDashMonth(delta) {
    calendar.step(delta)
    return calendar.cursor.toLocaleString(Theme.locale, "MMMM yyyy")
  }

  onOpened: {
    resetPick()
    syncPosition()
  }

  onScrolled: root.closePopup(playerPopup)

  Connections {
    target: root.target

    function onPositionChanged() {
      root.localPosition = root.target.position
    }

    function onMetadataChanged() {
      root.syncPosition()
    }

    function onIsPlayingChanged() {
      if (root.target && root.target.isPlaying) {
        root.syncPosition()
      }
    }
  }

  Column {
    id: mprisColumn

    visible: root.target !== null
    width: parent.width
    spacing: s(10)

    Item {
      width: parent.width
      height: artWrap.height

      Rectangle {
        id: artWrap

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: s(92)
        height: width
        radius: s(10)
        color: Theme.surfaceHigh
        antialiasing: true
        border.width: hairline()
        border.color: Qt.rgba(1, 1, 1, 0.2)
        clip: true

        Item {
          anchors.fill: parent
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: artMask
            maskSpreadAtMin: 1.0
            maskThresholdMin: 0.5
          }

          Icon {
            anchors.centerIn: parent
            visible: !(root.target && root.target.trackArtUrl.length > 0)
            name: "music"
            font.pixelSize: s(30)
            color: Theme.overlay
          }

          Image {
            anchors.fill: parent
            visible: root.target && root.target.trackArtUrl.length > 0
            source: root.target ? root.target.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            sourceSize.width: artWrap.width * 2
            sourceSize.height: artWrap.height * 2
          }
        }

        Rectangle {
          id: artMask

          anchors.fill: parent
          visible: false
          radius: artWrap.radius
          color: "white"
          antialiasing: true
          layer.enabled: true
        }
      }

      Column {
        id: textColumn

        anchors.left: artWrap.right
        anchors.leftMargin: s(15)
        anchors.verticalCenter: parent.verticalCenter
        spacing: s(5)
        width: parent.width - artWrap.width - s(15)

        Item {
          width: parent.width
          height: identityRow.implicitHeight

          Row {
            id: identityRow

            spacing: s(5)

            Icon {
              anchors.verticalCenter: parent.verticalCenter
              name: "devices"
              font.pixelSize: s(11)
              lineHeight: s(11)
              lineHeightMode: Text.FixedHeight
              color: Theme.mauve
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: identityRow.parent.width - identityRow.spacing - s(11)
              text: root.target ? root.target.identity || "Unknown player" : ""
              color: Theme.subtext
              font.family: "monospace"
              font.pixelSize: s(9)
              lineHeight: s(11)
              lineHeightMode: Text.FixedHeight
              elide: Text.ElideRight
            }
          }
        }

        Text {
          width: parent.width
          height: Math.min(implicitHeight, s(34))
          verticalAlignment: Text.AlignVCenter
          text: root.target ? root.target.trackTitle.length > 0 ? root.target.trackTitle : "Unknown title" : ""
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: s(16)
          font.bold: true
          lineHeight: s(17)
          lineHeightMode: Text.FixedHeight
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          height: s(12)
          verticalAlignment: Text.AlignVCenter
          text: {
            if (!root.target) {
              return ""
            }
            const artist = root.target.trackArtist && root.target.trackArtist.length > 0 ? root.target.trackArtist : "Unknown artist"
            const album = root.target.trackAlbum && root.target.trackAlbum.length > 0 ? " · " + root.target.trackAlbum : ""
            return artist + album
          }
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: s(10)
          font.weight: Font.Medium
          elide: Text.ElideRight
          visible: root.target !== null
        }
      }

      Rectangle {
        id: playerBtn

        anchors.top: parent.top
        anchors.right: parent.right
        width: s(20)
        height: s(20)
        radius: s(10)
        visible: root.multiPlayer
        color: playerBtnHover.containsMouse || playerPopup.opened ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)

        Text {
          anchors.centerIn: parent
          text: Icons.get("playlist")
          font.family: Theme.iconFamily
          font.pixelSize: s(11)
          color: Theme.text
        }

        MouseArea {
          id: playerBtnHover

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openPopupAt(playerPopup, playerBtn)
        }
      }
    }

    Item {
      width: parent.width
      height: seekTrack.height + s(4) + elapsedText.implicitHeight
      visible: root.target && root.target.positionSupported && root.target.lengthSupported && root.target.length > 0
      implicitHeight: visible ? height : 0

      Text {
        id: elapsedText

        anchors.left: parent.left
        anchors.top: seekTrack.bottom
        anchors.topMargin: s(4)
        text: root.fmtTime(root.seeking ? root.seekPreview * root.target.length : root.localPosition)
        color: Theme.subtext
        font.family: "monospace"
        font.pixelSize: s(10)
      }

      Text {
        anchors.right: parent.right
        anchors.top: seekTrack.bottom
        anchors.topMargin: s(4)
        text: root.fmtTime(root.target.length)
        color: Theme.subtext
        font.family: "monospace"
        font.pixelSize: s(10)
      }

      Rectangle {
        id: seekTrack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: s(5)
        radius: height / 2
        color: Theme.surfaceHigh

        Rectangle {
          width: Math.round((seekTrack.width - seekKnob.width) * (root.seeking ? root.seekPreview : root.seekFraction) + seekKnob.width / 2)
          height: parent.height
          radius: parent.radius
          color: Theme.mauve

          Behavior on width {
            enabled: !root.seeking
            NumberAnimation {
              duration: 300
              easing.type: Easing.OutCubic
            }
          }
        }

        Rectangle {
          id: seekKnob

          x: Math.round((seekTrack.width - width) * (root.seeking ? root.seekPreview : root.seekFraction))
          y: Math.round((seekTrack.height - height) / 2)
          width: s(11)
          height: s(11)
          radius: width / 2
          color: Theme.text

          Behavior on x {
            enabled: !root.seeking
            NumberAnimation {
              duration: 300
              easing.type: Easing.OutCubic
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.target && root.target.canSeek
          cursorShape: Qt.PointingHandCursor
          onClicked: mouse => {
            root.previewSeek(mouse.x / seekTrack.width)
            root.commitSeek()
          }
          onPositionChanged: mouse => {
            if (pressed) {
              root.previewSeek(mouse.x / seekTrack.width)
            }
          }
          onPressed: mouse => root.previewSeek(mouse.x / seekTrack.width)
          onReleased: root.commitSeek()
          onWheel: e => {
            root.wheelSeek(e.angleDelta.y)
            e.accepted = true
          }
        }
      }
    }

    Item {
      width: parent.width
      height: s(45)

      Rectangle {
        width: s(35)
        height: s(35)
        radius: s(17.5)
        x: parent.width * 3 / 10 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.target && root.target.canGoPrevious ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        color: prevHover.containsMouse && root.target && root.target.canGoPrevious ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)

        Text {
          anchors.centerIn: parent
          text: Icons.get("player-track-prev")
          font.family: Theme.iconFamily
          font.pixelSize: s(17)
          color: Theme.text
        }

        MouseArea {
          id: prevHover

          anchors.fill: parent
          hoverEnabled: true
          enabled: root.target && root.target.canGoPrevious
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.target) {
            root.target.previous()
          }
        }
      }

      Rectangle {
        width: s(44)
        height: s(44)
        radius: s(22)
        x: parent.width / 2 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: playHover.containsMouse ? Qt.lighter(Theme.mauve, 1.15) : Theme.mauve

        Text {
          anchors.centerIn: parent
          text: root.target && root.target.isPlaying ? Icons.get("player-pause") : Icons.get("player-play")
          font.family: Theme.iconFamily
          font.pixelSize: s(17)
          color: Theme.onAccent
        }

        MouseArea {
          id: playHover

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.target) {
            root.target.togglePlaying()
          }
        }
      }

      Rectangle {
        width: s(35)
        height: s(35)
        radius: s(17.5)
        x: parent.width * 7 / 10 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.target && root.target.canGoNext ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        color: nextHover.containsMouse && root.target && root.target.canGoNext ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)

        Text {
          anchors.centerIn: parent
          text: Icons.get("player-track-next")
          font.family: Theme.iconFamily
          font.pixelSize: s(17)
          color: Theme.text
        }

        MouseArea {
          id: nextHover

          anchors.fill: parent
          hoverEnabled: true
          enabled: root.target && root.target.canGoNext
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.target) {
            root.target.next()
          }
        }
      }
    }
  }

  Item {
    visible: root.target !== null
    width: parent.width
    height: hairline() + s(12)

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: s(6)
      width: parent.width
      height: hairline()
      color: Theme.surfaceHigh
    }
  }

  Item {
    width: parent.width
    height: calendar.implicitHeight

    CalendarView {
      id: calendar

      width: contentWidth
      x: Math.round((parent.width - width) / 2)
    }
  }

  Popup {
    id: playerPopup

    popupType: Popup.Item
    modal: false
    padding: s(3)
    width: s(176)
    height: playerColumn.implicitHeight + s(6)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onClosed: {
      if (root.routeDismissedAt === 0) {
        root.routeDismissedAt = Date.now()
      }
    }

    background: Rectangle {
      color: Theme.surfaceHigh
      radius: Theme.rowRadius
      border.width: 1
      border.color: Theme.surfaceHigher
      antialiasing: true
    }

    contentItem: Column {
      id: playerColumn

      spacing: s(1)

      Repeater {
        model: root.players

        delegate: Item {
          id: playerOption

          required property var modelData

          readonly property bool current: root.target === modelData

          width: playerColumn.width
          height: s(22)

          Rectangle {
            anchors.fill: parent
            radius: s(6)
            color: playerMouse.containsMouse ? Theme.surfaceHigher : "transparent"
            antialiasing: true
          }

          Item {
            id: playerCheck

            anchors.left: parent.left
            anchors.leftMargin: s(6)
            anchors.verticalCenter: parent.verticalCenter
            width: s(16)
            height: width

            Icon {
              anchors.centerIn: parent
              visible: playerOption.current
              name: "check"
              color: Theme.primary
              font.pixelSize: s(9)
            }
          }

          Text {
            anchors.left: playerCheck.right
            anchors.leftMargin: s(4)
            anchors.right: parent.right
            anchors.rightMargin: s(6)
            anchors.verticalCenter: parent.verticalCenter
            text: playerOption.modelData.identity || "Unknown player"
            color: playerOption.current ? Theme.text : Theme.subtext
            font.family: "monospace"
            font.pixelSize: s(10)
            elide: Text.ElideRight
          }

          MouseArea {
            id: playerMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.picked = playerOption.modelData
              root.closePopup(playerPopup)
            }
          }
        }
      }
    }
  }

  Timer {
    id: seekCommitTimer

    interval: 200
    onTriggered: root.commitSeek()
  }

  Timer {
    id: positionTicker

    interval: 250
    repeat: true
    running: root.open && root.target !== null && root.target.isPlaying && !root.seeking
    onTriggered: root.localPosition += 0.25
  }

  Timer {
    id: positionPoll

    interval: 1000
    repeat: true
    running: root.open && root.target !== null && root.target.isPlaying && root.target.positionSupported
    onTriggered: {
      if (root.target) {
        positionProc.command = ["playerctl", "-p", root.target.dbusName, "position"]
        positionProc.running = true
      }
    }
  }

  Process {
    id: positionProc

    command: ["true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const value = parseFloat(text)
        if (!isNaN(value) && root.target) {
          root.localPosition = Math.max(0, Math.min(value, root.target.length > 0 ? root.target.length : value))
        }
      }
    }
  }
}
