import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  active: Panels.openOn("volume", root.screen.name)

  onClicked: Panels.toggle("volume", root.screen.name)

  onRightClicked: {
    Audio.toggleMute();
    Osd.show(Audio.muted ? "volume-off" : "volume-3", Math.round(Audio.volume * 100) + "%", Audio.muted ? 0 : Audio.volume);
  }

  onMiddleClicked: Quickshell.execDetached(["systemctl", "--user", "restart", "wireplumber"])

  onWheeled: (delta) => {
    Audio.changeVolume(delta > 0 ? 0.05 : -0.05);
    Osd.show(Audio.muted ? "volume-off" : "volume-3", Math.round(Audio.volume * 100) + "%", Audio.muted ? 0 : Audio.volume);
  }

  VolumeIcon {
    visible: !Audio.muted
    anchors.centerIn: parent
    level: Audio.volume
    color: Theme.text
  }

  Icon {
    visible: Audio.muted
    anchors.centerIn: parent
    name: "volume-off"
    color: Theme.overlay
    font.pixelSize: Theme.iconSizeLarge
  }
}
