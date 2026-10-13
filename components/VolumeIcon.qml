import QtQuick
import QtQuick.Shapes
import "../theme"

Item {
  id: root

  property real level: 0
  property real maxLevel: 1.5
  property color color: Theme.text
  property color overColor: Theme.red

  implicitWidth: Theme.iconSizeLarge
  implicitHeight: Theme.iconSizeLarge

  readonly property real u: Math.min(width, height) / 24
  readonly property real strokeWidth: 2 * u
  readonly property int waves: level <= 0 ? 0 : level <= 0.34 ? 1 : level <= 0.67 ? 2 : 3
  readonly property real overStep: (maxLevel - 1) / 4
  readonly property int redWaves: Math.round(level * 100) < 101 ? 0 : Math.min(3, 1 + Math.floor((level - 1) / overStep))

  function waveColor(index) {
    if (index > waves) {
      return "transparent"
    }
    return index <= redWaves ? overColor : color
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      fillColor: "transparent"
      startX: 6 * root.u
      startY: 15 * root.u

      PathLine {
        x: 4 * root.u
        y: 15 * root.u
      }
      PathLine {
        x: 3 * root.u
        y: 14 * root.u
      }
      PathLine {
        x: 3 * root.u
        y: 10 * root.u
      }
      PathLine {
        x: 4 * root.u
        y: 9 * root.u
      }
      PathLine {
        x: 6 * root.u
        y: 9 * root.u
      }
      PathLine {
        x: 9.5 * root.u
        y: 4.5 * root.u
      }
      PathLine {
        x: 11 * root.u
        y: 5 * root.u
      }
      PathLine {
        x: 11 * root.u
        y: 19 * root.u
      }
      PathLine {
        x: 9.5 * root.u
        y: 19.5 * root.u
      }
      PathLine {
        x: 6 * root.u
        y: 15 * root.u
      }
    }

    ShapePath {
      strokeColor: root.waveColor(1)
      strokeWidth: root.strokeWidth
      capStyle: ShapePath.RoundCap
      fillColor: "transparent"

      PathAngleArc {
        moveToStart: true
        centerX: 12 * root.u
        centerY: 12 * root.u
        radiusX: 5 * root.u
        radiusY: 5 * root.u
        startAngle: -52
        sweepAngle: 104
      }
    }

    ShapePath {
      strokeColor: root.waveColor(2)
      strokeWidth: root.strokeWidth
      capStyle: ShapePath.RoundCap
      fillColor: "transparent"

      PathAngleArc {
        moveToStart: true
        centerX: 12 * root.u
        centerY: 12 * root.u
        radiusX: 9 * root.u
        radiusY: 9 * root.u
        startAngle: -52
        sweepAngle: 104
      }
    }

    ShapePath {
      strokeColor: root.waveColor(3)
      strokeWidth: root.strokeWidth
      capStyle: ShapePath.RoundCap
      fillColor: "transparent"

      PathAngleArc {
        moveToStart: true
        centerX: 12 * root.u
        centerY: 12 * root.u
        radiusX: 13 * root.u
        radiusY: 13 * root.u
        startAngle: -52
        sweepAngle: 104
      }
    }
  }
}
