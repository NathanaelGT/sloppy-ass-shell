pragma Singleton
import Quickshell
import Quickshell.Services.Notifications

Singleton {
  readonly property alias server: instance

  property bool dnd: false

  readonly property var active: instance.trackedNotifications

  function dismissAll() {
    const list = active;
    if (!list) return;
    for (let i = 0; i < list.length; i++) list[i].dismiss();
  }

  NotificationServer {
    id: instance
    keepOnReload: true
  }
}
