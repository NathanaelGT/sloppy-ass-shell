pragma Singleton
import Quickshell

Singleton {
  function describe(cls) {
    if (!cls) {
      return null
    }
    const exact = DesktopEntries.heuristicLookup(cls)
    if (exact && (exact.icon || exact.name)) {
      return {
        name: exact.name ? String(exact.name) : String(cls),
        icon: exact.icon ? String(exact.icon) : ""
      }
    }
    const all = DesktopEntries.applications ? DesktopEntries.applications.values : []
    const lower = String(cls).toLowerCase()
    for (let i = 0; i < all.length; i++) {
      const entry = all[i]
      const id = entry.id ? String(entry.id).toLowerCase() : ""
      const sc = entry.startupClass ? String(entry.startupClass).toLowerCase() : ""
      const nm = entry.name ? String(entry.name).toLowerCase() : ""
      if (id === lower || sc === lower || nm === lower || id.indexOf(lower + "-") === 0 || lower.indexOf(id + "-") === 0 || (sc && (sc.indexOf(lower + "-") === 0 || lower.indexOf(sc + "-") === 0))) {
        return {
          name: entry.name ? String(entry.name) : String(cls),
          icon: entry.icon ? String(entry.icon) : ""
        }
      }
    }
    return null
  }

  function resolve(cls) {
    if (!cls) {
      return ""
    }
    const d = describe(cls)
    if (d && d.icon) {
      return d.icon
    }
    return cls
  }
}
