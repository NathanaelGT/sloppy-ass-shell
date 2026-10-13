import QtQuick
import "../theme"

Rectangle {
  id: root

  property string icon: ""
  property string text: ""
  property bool shown: false
  property bool instant: false
  property bool rolling: false
  property bool displayed: false
  property string shownIcon: ""
  property int dotCount: 1
  property int dotDir: 1

  readonly property bool morphActive: settleTimer.running || baseMorph.morphing

  width: parent ? parent.width : 0
  height: displayed ? Math.round(76 * Theme.scale) + Theme.gap : 0
  radius: Theme.rowRadius
  color: Theme.surface
  antialiasing: true
  visible: displayed
  clip: true

  Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

  function advanceDots() {
    dotCount += dotDir;
    if (dotCount >= 3) {
      dotCount = 3;
      dotDir = -1;
    } else if (dotCount <= 1) {
      dotCount = 1;
      dotDir = 1;
    }
  }

  function appear() {
    if (!root.shown) return;
    fadeInAnim.stop();
    baseMorph.setInstant(root.text);
    root.shownIcon = root.icon;
    root.dotCount = 1;
    root.dotDir = 1;
    dotsMorph.setInstant(".");
    root.opacity = root.instant ? 1 : 0;
    root.displayed = true;
    if (!root.instant) fadeInAnim.restart();
  }

  function hideCard() {
    fadeInAnim.stop();
    settleTimer.stop();
    baseMorph.setInstant(root.text);
    root.shownIcon = root.icon;
    root.opacity = 1;
    root.displayed = false;
  }

  function settle() {
    if (!root.displayed) return;
    if (root.instant) {
      settleTimer.stop();
      baseMorph.setInstant(root.text);
      root.shownIcon = root.icon;
    } else settleTimer.restart();
  }

  onTextChanged: Qt.callLater(root.settle)

  onShownChanged: {
    if (shown) Qt.callLater(root.appear);
    else root.hideCard();
  }

  onRollingChanged: {
    if (rolling) {
      root.dotCount = 1;
      root.dotDir = 1;
      dotsMorph.setInstant(".");
    }
  }

  onMorphActiveChanged: {
    if (!morphActive && root.displayed) root.shownIcon = root.icon;
  }

  Component.onCompleted: {
    baseMorph.setInstant(root.text);
    root.shownIcon = root.icon;
    if (root.shown) root.appear();
  }

  Timer {
    id: settleTimer

    interval: 200
    onTriggered: baseMorph.morphTo(root.text)
  }

  NumberAnimation {
    id: fadeInAnim

    target: root
    property: "opacity"
    from: 0
    to: 1
    duration: 160
    easing.type: Easing.OutCubic
  }

  Timer {
    id: dotsTimer

    interval: 600
    repeat: true
    running: root.rolling && root.displayed && !root.morphActive
    onTriggered: {
      root.advanceDots();
      dotsMorph.morphTo("...".substring(0, root.dotCount));
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(8 * Theme.scale)

    Icon {
      anchors.horizontalCenter: parent.horizontalCenter
      name: root.shownIcon
      color: Theme.overlay
      font.pixelSize: Math.round(22 * Theme.scale)
    }

    Item {
      id: swapBox

      width: baseMorph.implicitWidth
      height: baseMorph.implicitHeight

      Behavior on width {
        enabled: root.morphActive
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
      }

      Item {
        id: textBox

        anchors.fill: parent

        MorphText {
          id: baseMorph

          anchors.fill: parent
          fontFamily: Theme.fontFamily
          fontPixelSize: Theme.fontSizeSmall
          textColor: Theme.subtext
        }

        MorphText {
          id: dotsMorph

          x: Math.round((parent.width - baseMorph.contentWidth) / 2 + baseMorph.contentWidth + Math.round(4 * Theme.scale))
          height: baseMorph.implicitHeight
          anchors.verticalCenter: parent.verticalCenter
          visible: root.rolling && !root.morphActive
          fontFamily: Theme.fontFamily
          fontPixelSize: Theme.fontSizeSmall
          textColor: Theme.subtext
        }
      }
    }
  }
}
