import QtQuick
import "../theme"

ListView {
  id: root

  property var entries: []
  property var sections: ({})

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

  function sync() {
    const rows = root.entries ? root.entries : []
    const wanted = {}
    for (let j = 0; j < rows.length; j++) {
      const entry = rows[j]
      let key = root.entryKey(entry)
      if (entry.kind !== "label") {
        let n = 0
        while (wanted[key] !== undefined) {
          n += 1
          key = root.entryKey(entry) + "#" + n
        }
      }
      wanted[key] = j
    }
    for (let i = model.count - 1; i >= 0; i--) {
      if (wanted[model.get(i).key] === undefined) {
        model.remove(i)
      }
    }
    for (let j = 0; j < rows.length; j++) {
      const entry = rows[j]
      const fields = root.rowFields(entry)
      let key = root.entryKey(entry)
      if (entry.kind !== "label") {
        let n = 0
        while (wanted[key] !== undefined && wanted[key] !== j) {
          n += 1
          key = root.entryKey(entry) + "#" + n
        }
      }
      wanted[key] = j
      let at = -1
      for (let i = 0; i < model.count; i++) {
        if (model.get(i).key === key) {
          at = i
          break
        }
      }
      if (at < 0) {
        model.insert(j, {
          key: key,
          kind: fields.kind,
          section: fields.section,
          label: fields.label,
          itemKey: fields.itemKey,
          active: fields.active
        })
      } else {
        if (at !== j) {
          model.move(at, j, 1)
        }
        if (model.get(j).kind !== fields.kind) {
          model.setProperty(j, "kind", fields.kind)
        }
        if (model.get(j).section !== fields.section) {
          model.setProperty(j, "section", fields.section)
        }
        if (model.get(j).label !== fields.label) {
          model.setProperty(j, "label", fields.label)
        }
        if (model.get(j).itemKey !== fields.itemKey) {
          model.setProperty(j, "itemKey", fields.itemKey)
        }
        if (model.get(j).active !== fields.active) {
          model.setProperty(j, "active", fields.active)
        }
      }
    }
  }

  onEntriesChanged: root.sync()
  Component.onCompleted: root.sync()

  width: parent ? parent.width : 0
  height: contentHeight
  implicitHeight: height
  spacing: Theme.gap
  interactive: false
  focus: false
  clip: true
  model: internal

  ListModel {
    id: internal
  }
}
