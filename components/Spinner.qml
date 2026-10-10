import QtQuick
import QtQuick.Shapes
import "../theme"

Item {
  id: root

  property color color: Theme.primary
  property bool running: true

  implicitWidth: Math.round(16 * Theme.scale)
  implicitHeight: implicitWidth

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.color
      strokeWidth: Math.round(2 * Theme.scale)
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        moveToStart: true
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: root.width / 2 - Math.round(2 * Theme.scale)
        radiusY: root.height / 2 - Math.round(2 * Theme.scale)
        startAngle: 0
        sweepAngle: 280
      }
    }
  }

  RotationAnimator on rotation {
    from: 0
    to: 360
    duration: 900
    loops: Animation.Infinite
    running: root.running
  }
}
