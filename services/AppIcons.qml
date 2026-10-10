pragma Singleton
import Quickshell

Singleton {
  function resolve(cls) {
    if (!cls) return "";
    const exact = DesktopEntries.heuristicLookup(cls);
    if (exact && exact.icon) return exact.icon;
    const all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
    const lower = String(cls).toLowerCase();
    for (let i = 0; i < all.length; i++) {
      const entry = all[i];
      const id = entry.id ? String(entry.id).toLowerCase() : "";
      const sc = entry.startupClass ? String(entry.startupClass).toLowerCase() : "";
      const nm = entry.name ? String(entry.name).toLowerCase() : "";
      if (id === lower || sc === lower || nm === lower) return entry.icon ? entry.icon : cls;
      if (id.indexOf(lower + "-") === 0 || lower.indexOf(id + "-") === 0) return entry.icon ? entry.icon : cls;
      if (sc && (sc.indexOf(lower + "-") === 0 || lower.indexOf(sc + "-") === 0)) return entry.icon ? entry.icon : cls;
    }
    return cls;
  }
}
