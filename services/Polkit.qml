pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
  id: root

  readonly property alias agent: instance
  readonly property var realFlow: instance.flow
  property QtObject testFlow: null
  readonly property var flow: realFlow !== null ? realFlow : testFlow
  readonly property bool active: realFlow !== null || testFlow !== null
  readonly property bool fakeActive: realFlow === null && testFlow !== null
  property string targetScreen: ""
  property var lastFlow: null
  readonly property string pinScreen: {
    const screens = Quickshell.screens
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name === targetScreen) {
        return targetScreen
      }
    }
    return Hypr.focusedScreenName
  }

  function testShow(screen) {
    if (LockState.sessionLocked) {
      return "locked"
    }
    if (realFlow !== null) {
      return "busy"
    }
    root.targetScreen = screen && screen.length > 0 ? screen : Hypr.focusedScreenName
    fakeFlow.supplementaryMessage = ""
    root.testFlow = fakeFlow
    return "shown"
  }

  function testHide() {
    if (root.testFlow === null) {
      return "idle"
    }
    root.testFlow = null
    if (realFlow === null) {
      root.targetScreen = ""
    }
    return "hidden"
  }

  function testFail() {
    if (root.testFlow === null) {
      return "no-fake"
    }
    fakeFlow.authenticationFailed()
    return "failed"
  }

  QtObject {
    id: fakeFlow

    property string message: "Authentication is required to run the test seam"
    property string inputPrompt: "Password:"
    property bool responseVisible: false
    property string supplementaryMessage: ""
    property bool supplementaryIsError: false

    signal authenticationFailed

    function submit(value) {
    }

    function cancelAuthenticationRequest() {
    }
  }

  PolkitAgent {
    id: instance

    onFlowChanged: {
      if (instance.flow === root.lastFlow) {
        return
      }
      root.lastFlow = instance.flow
      if (instance.flow === null) {
        if (root.testFlow === null) {
          root.targetScreen = ""
        }
        return
      }
      root.targetScreen = Hypr.focusedScreenName
    }
  }
}
