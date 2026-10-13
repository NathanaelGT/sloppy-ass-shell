import QtQuick
import Quickshell.Services.Pipewire
import "../theme"

Item {
  id: root

  property real value: 0
  property real fullMark: -1
  property color fillColor: Theme.primary
  property var node: null

  signal moved(real value)
  signal wheeled(real angleDelta)

  implicitHeight: Math.round(16 * Theme.scale)

  readonly property int historySize: 48
  property var history: []
  property bool live: false

  function clamp(v) {
    return Math.max(0, Math.min(1, v))
  }

  onNodeChanged: {
    root.history = []
    root.live = false
  }

  PwNodePeakMonitor {
    id: peakMon
    node: root.node
    enabled: root.node !== null
  }

  Timer {
    interval: 50
    running: root.node !== null
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      const next = root.history.slice(-(root.historySize - 1))
      next.push(Math.max(0, Math.min(1, peakMon.peak)))
      root.history = next
      let peak = 0
      for (let i = 0; i < next.length; i++) {
        if (next[i] > peak) {
          peak = next[i]
        }
      }
      if (peak >= 0.02) {
        root.live = true
      } else if (peak < 0.008) {
        root.live = false
      }
      if (root.live) {
        waveCanvas.requestPaint()
      }
    }
  }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: Math.round(2 * Theme.scale)
    radius: height / 2
    color: Theme.trackFill
    antialiasing: true
  }

  Rectangle {
    visible: root.fullMark >= 0
    anchors.verticalCenter: parent.verticalCenter
    x: root.clamp(root.fullMark) * track.width - width / 2
    width: track.height
    height: knob.height
    radius: width / 2
    color: Theme.trackFill
    antialiasing: true
  }

  Rectangle {
    visible: root.node === null || !root.live
    anchors.verticalCenter: parent.verticalCenter
    width: root.clamp(root.value) * track.width
    height: track.height
    radius: track.radius
    color: root.fillColor
    antialiasing: true

    Behavior on width {
      enabled: !slideMouse.pressed
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutCubic
      }
    }
  }

  Item {
    visible: root.node !== null && root.live
    anchors.verticalCenter: parent.verticalCenter
    width: root.clamp(root.value) * track.width
    height: Math.round(10 * Theme.scale)
    clip: true

    Behavior on width {
      enabled: !slideMouse.pressed
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutCubic
      }
    }

    Canvas {
      id: waveCanvas
      width: parent.width
      height: parent.height
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      onWidthChanged: requestPaint()

      onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0) {
          return
        }
        ctx.fillStyle = root.fillColor
        const n = root.history.length
        const mid = Math.floor(height / 2)
        const flat = Math.max(2, track.height)
        if (n === 0) {
          ctx.fillRect(0, mid - Math.floor(flat / 2), width, flat)
          return
        }
        const step = width / Math.max(1, root.historySize - 1)
        const top = []
        const bottom = []
        for (let i = 0; i < n; i++) {
          const raw = Math.max(0, Math.min(1, root.history[n - 1 - i]))
          const p = raw < 0.02 ? 0 : raw
          const h = Math.max(flat, Math.round(p * height))
          const x = Math.floor(width - i * step)
          top.push([x, Math.floor(mid - h / 2)])
          bottom.push([x, Math.ceil(mid + h / 2)])
        }
        ctx.beginPath()
        ctx.moveTo(width, mid - Math.floor(flat / 2))
        for (let i = 0; i < top.length; i++) {
          ctx.lineTo(top[i][0], top[i][1])
        }
        ctx.lineTo(Math.floor(width - (n - 1) * step), mid - Math.floor(flat / 2))
        ctx.lineTo(0, mid - Math.floor(flat / 2))
        ctx.lineTo(0, mid + Math.ceil(flat / 2))
        ctx.lineTo(Math.floor(width - (n - 1) * step), mid + Math.ceil(flat / 2))
        for (let i = 0; i < bottom.length; i++) {
          ctx.lineTo(bottom[bottom.length - 1 - i][0], bottom[bottom.length - 1 - i][1])
        }
        ctx.lineTo(width, mid + Math.ceil(flat / 2))
        ctx.closePath()
        ctx.fill()
      }
    }
  }

  Rectangle {
    id: knob
    anchors.verticalCenter: parent.verticalCenter
    width: Math.round(10 * Theme.scale)
    height: width
    radius: width / 2
    color: Theme.knobFill
    x: root.clamp(root.value) * (track.width - width)
    antialiasing: true

    Behavior on x {
      enabled: !slideMouse.pressed
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutCubic
      }
    }
  }

  MouseArea {
    id: slideMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: e => root.moved(root.clamp(e.x / track.width))
    onPositionChanged: e => {
      if (pressed) {
        root.moved(root.clamp(e.x / track.width))
      }
    }
    onWheel: e => {
      root.wheeled(e.angleDelta.y)
      e.accepted = true
    }
  }
}
