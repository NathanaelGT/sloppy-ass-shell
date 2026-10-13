import QtQuick
import "../theme"
import "../services/QrCode.js" as QrCode

Item {
  id: root

  property string text: ""
  property int ecc: 1
  property color moduleColor: Theme.crust
  readonly property var matrix: root.text.length > 0 ? QrCode.encode(root.text, root.ecc) : null

  function paint(context) {
    context.clearRect(0, 0, canvas.width, canvas.height)
    const grid = root.matrix;
    if (!grid) return;
    const cell = Math.min(canvas.width, canvas.height) / grid.size;
    context.fillStyle = String(root.moduleColor);
    for (let y = 0; y < grid.size; y++) {
      const top = Math.round(y * cell);
      const bottom = Math.round((y + 1) * cell);
      for (let x = 0; x < grid.size; x++) {
        if (!grid.modules[y][x]) continue;
        const left = Math.round(x * cell);
        const right = Math.round((x + 1) * cell);
        context.fillRect(left, top, right - left, bottom - top);
      }
    }
  }

  Canvas {
    id: canvas

    anchors.fill: parent
    antialiasing: false
    onPaint: root.paint(canvas.getContext("2d"))
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
  }

  onMatrixChanged: canvas.requestPaint()
}
