import QtQuick
import "../theme"

ListView {
  id: root

  property var entries: []
  property var sections: ({})
  property bool reorderAnimation: true
  property bool fadeAnimation: true

  signal sectionToggled(string section)

  function isExpanded(section) {
    return root.sections[section] === undefined ? true : root.sections[section]
  }

  function toggleSection(section) {
    root.sectionToggled(section)
  }

  function entryKey(entry) {
    return entry.kind === "label" ? "label:" + entry.section : "item:" + String(entry.itemKey)
  }

  function rowFields(entry) {
    const isLabel = entry.kind === "label"
    return {
      kind: entry.kind,
      section: entry.section,
      label: isLabel ? (entry.text === undefined ? "" : entry.text) : "",
      itemKey: isLabel ? "" : String(entry.itemKey),
      active: isLabel ? false : entry.active === true
    }
  }

  function wantedRows() {
    const rows = root.entries ? root.entries : []
    const keys = []
    const fields = []
    const used = {}
    for (let j = 0; j < rows.length; j++) {
      const entry = rows[j]
      let key = root.entryKey(entry)
      if (entry.kind !== "label") {
        let n = 0
        let candidate = key
        while (used[candidate] !== undefined) {
          n += 1
          candidate = key + "#" + n
        }
        key = candidate
      }
      used[key] = j
      keys.push(key)
      fields.push(root.rowFields(entry))
    }
    return {
      keys: keys,
      fields: fields
    }
  }

  function keyList() {
    const keys = []
    for (let i = 0; i < model.count; i++) {
      keys.push(model.get(i).key)
    }
    return keys
  }

  function sameSlice(a, b, offsetA, offsetB, length) {
    for (let i = 0; i < length; i++) {
      if (a[offsetA + i] !== b[offsetB + i]) {
        return false
      }
    }
    return true
  }

  function relocation(keys, current) {
    if (keys.length !== current.length) {
      return null
    }
    let start = 0
    while (start < keys.length && keys[start] === current[start]) {
      start += 1
    }
    if (start === keys.length) {
      return null
    }
    let end = keys.length - 1
    while (end > start && keys[end] === current[end]) {
      end -= 1
    }
    if (current[start] === keys[end] && root.sameSlice(keys, current, start, start + 1, end - start)) {
      return {
        from: start,
        to: end
      }
    }
    if (current[end] === keys[start] && root.sameSlice(keys, current, start + 1, start, end - start)) {
      return {
        from: end,
        to: start
      }
    }
    return null
  }

  function sync() {
    const wanted = root.wantedRows()
    const keys = wanted.keys
    const current = root.keyList()
    for (let i = current.length - 1; i >= 0; i--) {
      if (keys.indexOf(current[i]) < 0) {
        model.remove(i)
        current.splice(i, 1)
      }
    }
    for (let j = 0; j < keys.length; j++) {
      if (current.indexOf(keys[j]) < 0) {
        const fields = wanted.fields[j]
        model.insert(j, {
          key: keys[j],
          kind: fields.kind,
          section: fields.section,
          label: fields.label,
          itemKey: fields.itemKey,
          active: fields.active
        })
        current.splice(j, 0, keys[j])
      }
    }
    const plan = root.relocation(keys, current)
    if (plan) {
      model.move(plan.from, plan.to, 1)
    } else {
      for (let j = 0; j < keys.length; j++) {
        let at = -1
        for (let i = 0; i < model.count; i++) {
          if (model.get(i).key === keys[j]) {
            at = i
            break
          }
        }
        if (at !== j && at >= 0) {
          model.move(at, j, 1)
        }
      }
    }
    for (let j = 0; j < keys.length; j++) {
      const fields = wanted.fields[j]
      const row = model.get(j)
      if (row.kind !== fields.kind) {
        model.setProperty(j, "kind", fields.kind)
      }
      if (row.section !== fields.section) {
        model.setProperty(j, "section", fields.section)
      }
      if (row.label !== fields.label) {
        model.setProperty(j, "label", fields.label)
      }
      if (row.itemKey !== fields.itemKey) {
        model.setProperty(j, "itemKey", fields.itemKey)
      }
      if (row.active !== fields.active) {
        model.setProperty(j, "active", fields.active)
      }
    }
  }

  onEntriesChanged: root.sync()
  Component.onCompleted: root.sync()

  function testDebug() {
    const rows = []
    for (let i = 0; i < model.count; i++) {
      const row = model.get(i)
      rows.push({
        key: row.key,
        kind: row.kind,
        itemKey: row.itemKey
      })
    }
    const items = []
    for (let i = 0; i < contentItem.children.length; i++) {
      const child = contentItem.children[i]
      if (child && child.key !== undefined) {
        items.push({
          key: String(child.key),
          kind: String(child.kind),
          itemKey: String(child.itemKey),
          y: Math.round(child.y),
          h: Math.round(child.height),
          o: Math.round(child.opacity * 100) / 100
        })
      }
    }
    return {
      rows: rows,
      items: items
    }
  }

  width: parent ? parent.width : 0
  height: contentHeight
  implicitHeight: height
  spacing: Theme.gap
  interactive: false
  focus: false
  clip: true
  model: internal

  move: Transition {
    NumberAnimation {
      property: "y"
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  displaced: Transition {
    enabled: root.reorderAnimation
    NumberAnimation {
      property: "y"
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  add: Transition {
    enabled: root.fadeAnimation
    NumberAnimation {
      property: "opacity"
      from: 0
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  remove: Transition {
    enabled: root.fadeAnimation
    NumberAnimation {
      property: "opacity"
      to: 0
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  ListModel {
    id: internal
  }
}
