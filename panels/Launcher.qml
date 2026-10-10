import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "launcher"
  align: "center"
  topMargin: Math.round((modelData ? modelData.height : 0) * 0.16)
  cardWidth: Math.min((modelData ? modelData.width : 0) - Math.round(80 * Theme.scale), Math.round(760 * Theme.scale))
  maxCardHeight: Math.round((modelData ? modelData.height : 0) * 0.7)
  exclusiveFocus: true
  autoFocusKeyCatcher: false

  property string query: ""

  readonly property var matches: {
    const model = DesktopEntries.applications;
    const all = model ? model.values : [];
    const q = root.query.trim().toLowerCase();
    const out = [];
    for (let i = 0; i < all.length; i++) {
      const app = all[i];
      if (app.noDisplay) continue;
      const name = app.name ? app.name : "";
      const rawKeywords = app.keywords;
      let keywords = "";
      if (typeof rawKeywords === "string") keywords = rawKeywords;
      else if (rawKeywords && typeof rawKeywords.length === "number") {
        for (let k = 0; k < rawKeywords.length; k++) keywords = keywords + " " + rawKeywords[k];
      } else if (rawKeywords) keywords = String(rawKeywords);
      if (q.length === 0 || name.toLowerCase().includes(q) || keywords.toLowerCase().includes(q)) out.push(app);
      if (out.length >= 60) break;
    }
    out.sort((a, b) => (a.name ? a.name : "").localeCompare(b.name ? b.name : ""));
    return out;
  }

  function launch(entry) {
    if (!entry) return;
    entry.execute();
    Panels.close();
  }

  onOpened: {
    query = "";
    search.forceActiveFocus();
  }

  Row {
    width: parent.width
    spacing: Math.round(8 * Theme.scale)

    Icon {
      anchors.verticalCenter: parent.verticalCenter
      name: "search"
      font.pixelSize: Theme.iconSizeLarge
    }

    TextInput {
      id: search
      width: parent.width - Math.round(40 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      color: Theme.text
      selectionColor: Theme.primary
      selectedTextColor: Theme.onAccent
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeLarge
      focus: true
      clip: true
      onTextChanged: root.query = text
      onAccepted: root.launch(root.matches.length > 0 ? root.matches[0] : null)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: search.text.length === 0
        text: "Search applications"
        color: Theme.overlay
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
      }

      Keys.onEscapePressed: Panels.close()
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: Theme.surfaceHigh
  }

  Grid {
    id: appsGrid

    columns: 6
    spacing: Math.round(8 * Theme.scale)
    width: parent.width

    Repeater {
      model: root.matches

      delegate: Rectangle {
        id: appCell

        required property var modelData

        width: (appsGrid.width - Math.round(5 * 8 * Theme.scale)) / 6
        height: width
        radius: Math.round(14 * Theme.scale)
        color: appMouse.containsMouse ? Theme.surface : "transparent"

        Column {
          anchors.centerIn: parent
          spacing: Math.round(6 * Theme.scale)
          width: parent.width

          Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(40 * Theme.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: Quickshell.iconPath(appCell.modelData.icon, "application-x-executable")
          }

          Text {
            width: parent.width
            text: appCell.modelData.name
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
          }
        }

        MouseArea {
          id: appMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.launch(appCell.modelData)
        }
      }
    }
  }
}
