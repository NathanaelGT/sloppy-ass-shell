pragma Singleton
import Quickshell

Singleton {
  id: root

  function hex(color) {
    function channel(v) {
      return Math.round(v * 255).toString(16).padStart(2, "0")
    }
    return "#" + channel(color.r) + channel(color.g) + channel(color.b)
  }
}
