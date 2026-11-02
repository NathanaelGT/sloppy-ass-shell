import QtQuick
import QtQuick.Shapes
import "../theme"

Item {
  id: root

  property color color: Theme.base
  property real radius: Theme.barThickness / 2
  property bool mirror: false

  implicitWidth: radius
  implicitHeight: radius
  width: radius
  height: radius

  Shape {
    width: root.radius
    height: root.radius
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.color
      strokeColor: "transparent"
      startX: root.mirror ? root.radius : 0
      startY: root.radius

      PathAngleArc {
        centerX: root.mirror ? root.radius : 0
        centerY: 0
        radiusX: root.radius
        radiusY: root.radius
        startAngle: 90
        sweepAngle: root.mirror ? 90 : -90
      }

      PathLine {
        x: root.mirror ? 0 : root.radius
        y: root.radius
      }
    }
  }
}
