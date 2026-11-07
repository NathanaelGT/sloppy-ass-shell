pragma Singleton
import Quickshell

Singleton {
  property string panel: ""
  property string screenName: ""
  property string barHoverScreen: ""
  property string closingScreen: ""
  signal closeCleared(string name, string screen)
  property var clusterWidths: ({})
  property var clusterRights: ({})
  property var trayItem: null
  property int trayAnchorX: -1

  function setMapValue(map, screen, value) {
    const next = Object.assign({}, map)
    next[screen] = value
    return next
  }

  function mapNumber(map, screen) {
    const value = map[screen]
    return typeof value === "number" ? value : 0
  }

  function setClusterWidth(screen, width) {
    clusterWidths = setMapValue(clusterWidths, screen, width)
  }

  function clusterWidth(screen) {
    return mapNumber(clusterWidths, screen)
  }

  function setClusterRight(screen, right) {
    clusterRights = setMapValue(clusterRights, screen, right)
  }

  function clusterRight(screen) {
    return mapNumber(clusterRights, screen)
  }

  function toggle(name, screen) {
    if (openOn(name, screen)) {
      close()
    } else {
      open(name, screen)
    }
  }

  function open(name, screen) {
    panel = name
    screenName = screen
  }

  function close() {
    panel = ""
    screenName = ""
  }

  function openTray(item, anchorX, screen) {
    trayItem = item
    trayAnchorX = anchorX
    open("tray", screen)
  }

  function openOn(name, screen) {
    return panel === name && screenName === screen
  }
}
