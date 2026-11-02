import QtQuick
import QtQuick.Shapes
import "../theme"

Item {
  id: root

  property color color: "transparent"
  property real radius: Theme.rowRadius

  implicitHeight: radius
  height: radius

  Shape {
    width: root.radius
    height: root.radius
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.color
      strokeColor: "transparent"

      PathLine {
        x: root.radius
        y: 0
      }

      PathAngleArc {
        centerX: root.radius
        centerY: root.radius
        radiusX: root.radius
        radiusY: root.radius
        startAngle: 270
        sweepAngle: -90
      }

      PathLine {
        x: 0
        y: 0
      }
    }
  }

  Shape {
    x: root.width - root.radius
    width: root.radius
    height: root.radius
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.color
      strokeColor: "transparent"

      PathLine {
        x: root.radius
        y: 0
      }

      PathLine {
        x: root.radius
        y: root.radius
      }

      PathAngleArc {
        centerX: 0
        centerY: root.radius
        radiusX: root.radius
        radiusY: root.radius
        startAngle: 0
        sweepAngle: -90
      }

      PathLine {
        x: 0
        y: 0
      }
    }
  }
}
