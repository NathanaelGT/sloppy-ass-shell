import QtQuick
import QtQuick.Shapes

Shape {
  id: root

  property color surfaceColor: "#000000"
  property real edgeMargin: 0
  property real cornerRadius: 0
  property real barWidth: width
  property real barHeight: height

  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    fillColor: root.surfaceColor
    strokeColor: "transparent"
    startX: root.edgeMargin - root.cornerRadius
    startY: 0

    PathLine {
      x: root.edgeMargin + root.barWidth + root.cornerRadius
      y: 0
    }
    PathQuad {
      x: root.edgeMargin + root.barWidth
      y: root.cornerRadius
      controlX: root.edgeMargin + root.barWidth
      controlY: 0
    }
    PathLine {
      x: root.edgeMargin + root.barWidth
      y: root.barHeight - root.cornerRadius
    }
    PathQuad {
      x: root.edgeMargin + root.barWidth - root.cornerRadius
      y: root.barHeight
      controlX: root.edgeMargin + root.barWidth
      controlY: root.barHeight
    }
    PathLine {
      x: root.edgeMargin + root.cornerRadius
      y: root.barHeight
    }
    PathQuad {
      x: root.edgeMargin
      y: root.barHeight - root.cornerRadius
      controlX: root.edgeMargin
      controlY: root.barHeight
    }
    PathLine {
      x: root.edgeMargin
      y: root.cornerRadius
    }
    PathQuad {
      x: root.edgeMargin - root.cornerRadius
      y: 0
      controlX: root.edgeMargin
      controlY: 0
    }
  }
}
