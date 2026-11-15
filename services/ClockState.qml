pragma Singleton
import Quickshell
import QtQuick
import "../theme"

Singleton {
  id: root

  property bool showAltTime: false

  SystemClock {
    id: clock

    precision: SystemClock.Seconds
  }

  readonly property date displayDate: root.showAltTime ? new Date(clock.date.getTime() + 3600000) : clock.date
  readonly property string dateText: root.displayDate.toLocaleString(Theme.locale, "dddd, d MMMM yyyy")
  readonly property string timeText: root.displayDate.toLocaleString(Theme.locale, "HH:mm:ss")
  readonly property string zoneText: root.showAltTime ? "WITA" : root.displayDate.toLocaleString(Theme.locale, "t")
}
