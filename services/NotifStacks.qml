pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
  id: root

  readonly property int gapSeconds: 3600

  function threadKeyOf(entry) {
    return String(entry.appName || "") + "\u001f" + String(entry.summary || "")
  }

  function soloKeyOf(entry) {
    return "\u001fsolo\u001f" + root.threadKeyOf(entry) + "\u001f" + entry.ts
  }

  function stackKeyOf(groupKey, oldestTs) {
    return groupKey + "\u001f" + oldestTs
  }

  function stackable(entry) {
    return entry.urgency !== NotificationUrgency.Critical && entry.transient !== true
  }

  function stacksFor(entries) {
    const groups = {}
    const groupKeys = []
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i]
      const groupKey = root.stackable(entry) ? root.threadKeyOf(entry) : root.soloKeyOf(entry)
      if (!groups[groupKey]) {
        groups[groupKey] = []
        groupKeys.push(groupKey)
      }
      groups[groupKey].push(entry)
    }
    const stacks = []
    for (let i = 0; i < groupKeys.length; i++) {
      const groupKey = groupKeys[i]
      const members = groups[groupKey].slice()
      members.sort((a, b) => b.ts - a.ts)
      const firstIndex = stacks.length
      let stack = null
      for (let j = 0; j < members.length; j++) {
        const entry = members[j]
        const previous = stack ? stack.members[stack.members.length - 1] : null
        if (!previous || previous.ts - entry.ts >= root.gapSeconds) {
          stack = {
            key: "",
            appName: String(entry.appName || ""),
            summary: String(entry.summary || ""),
            count: 0,
            active: false,
            day: entry.day,
            ts: entry.ts,
            sortId: 0,
            members: []
          }
          stacks.push(stack)
        }
        stack.members.push(entry)
        stack.count += 1
        stack.active = stack.active || entry.active === true
        stack.sortId = Math.max(stack.sortId, Number(entry.sortId) || 0)
      }
      for (let s = firstIndex; s < stacks.length; s++) {
        const stack = stacks[s]
        stack.key = root.stackKeyOf(groupKey, stack.members[stack.members.length - 1].ts)
      }
    }
    stacks.sort((a, b) => {
      if (a.ts !== b.ts) {
        return b.ts - a.ts
      }
      if (a.active !== b.active) {
        return a.active ? -1 : 1
      }
      return b.sortId - a.sortId
    })
    return stacks
  }
}
