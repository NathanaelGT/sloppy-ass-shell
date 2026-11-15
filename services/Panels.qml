pragma Singleton
import Quickshell

Singleton {
  property var openState: ({
      name: "",
      screen: ""
    })
  readonly property string panel: openState.name
  readonly property string screenName: openState.screen
  property string barHoverScreen: ""
  signal closeCleared(string name, string screen)
  property var clusterWidths: ({})
  property var clusterRights: ({})
  property var bannerMetrics: ({})
  property var bannerBell: ({})
  property var closingScreens: ({})
  property var trayItem: null
  property int trayAnchorX: -1
  property int cycleCount: 0

  function isClosing(screen) {
    return closingScreens[screen] === true
  }

  function setClosing(screen, closing) {
    const next = Object.assign({}, closingScreens)
    if (closing) {
      next[screen] = true
    } else {
      delete next[screen]
    }
    closingScreens = next
  }

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

  function setBannerMetrics(screen, metrics) {
    bannerMetrics = setMapValue(bannerMetrics, screen, metrics)
  }

  function bannerMetricsFor(screen) {
    return bannerMetrics[screen] || null
  }

  function setBannerBell(screen, bell) {
    bannerBell = setMapValue(bannerBell, screen, bell)
  }

  function bannerBellFor(screen) {
    return bannerBell[screen] || null
  }

  function toggle(name, screen) {
    if (openOn(name, screen)) {
      close()
    } else {
      open(name, screen)
    }
  }

  function cycle(name, screen) {
    if (LockState.sessionLocked) {
      return
    }
    if (openOn(name, screen)) {
      cycleCount = cycleCount + 1
    } else {
      open(name, screen)
    }
  }

  function open(name, screen) {
    if (LockState.sessionLocked) {
      return
    }
    openState = {
      name: name,
      screen: screen
    }
  }

  function close() {
    openState = {
      name: "",
      screen: ""
    }
  }

  function openTray(item, anchorX, screen) {
    if (openOn("tray", screen) && trayItem === item) {
      close()
      return
    }
    trayItem = item
    trayAnchorX = anchorX
    open("tray", screen)
  }

  function openOn(name, screen) {
    return panel === name && screenName === screen
  }
}
