pragma Singleton
import Quickshell

Singleton {
  property string panel: ""
  property string screenName: ""
  property string barHoverScreen: ""
  property string closingScreen: ""

  function toggle(name, screen) {
    if (openOn(name, screen)) close();
    else open(name, screen);
  }

  function open(name, screen) {
    panel = name;
    screenName = screen;
  }

  function close() {
    panel = "";
    screenName = "";
  }

  function openOn(name, screen) {
    return panel === name && screenName === screen;
  }
}
