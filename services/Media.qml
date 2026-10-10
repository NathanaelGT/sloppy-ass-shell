pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

Singleton {
  readonly property var players: Mpris.players ? Mpris.players.values : []

  readonly property var active: {
    const list = players;
    if (!list || list.length === 0) return null;
    for (let i = 0; i < list.length; i++) if (list[i].isPlaying) return list[i];
    return list[0];
  }
}
