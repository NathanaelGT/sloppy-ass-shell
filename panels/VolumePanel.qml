import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "volume"
  popupOpen: routePopup.opened
  animateCardHeight: true

  property var routeStream: null
  property var routeDismissed: null
  property real routeClosedAt: 0
  property bool outputExpanded: false
  property bool inputExpanded: false
  property bool appExpanded: false
  property bool measuring: false
  property var appOverrides: ({})
  property var appSnapshot: []
  property var streamNameCache: ({})
  property var iconCache: ({})
  property string activeSig: ""

  property var outputSticky: []
  property var inputSticky: []

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var defaultSink: Audio.sink
  readonly property var defaultSource: Audio.source

  function mediaClass(node) {
    if (!node || !node.properties) return "";
    const value = node.properties["media.class"];
    return value ? value : "";
  }

  function nodesOf(cls) {
    const out = [];
    for (let i = 0; i < nodes.length; i++) if (mediaClass(nodes[i]) === cls) out.push(nodes[i]);
    return out;
  }

  readonly property var sinks: nodesOf("Audio/Sink")
  readonly property var sources: nodesOf("Audio/Source")

  readonly property var playbackStreams: nodesOf("Stream/Output/Audio")
  readonly property var captureStreams: nodesOf("Stream/Input/Audio")
  readonly property var streams: playbackStreams.concat(captureStreams)

  function deviceList(kind) {
    return kind === "output" ? sinks : sources;
  }

  function deviceDefault(kind) {
    return kind === "output" ? defaultSink : defaultSource;
  }

  function devicePins(kind) {
    return kind === "output" ? Pins.outputs : Pins.inputs;
  }

  function streamRouteTarget(stream) {
    const props = streamProps(stream);
    const direct = props["target.object"] !== undefined ? props["target.object"] : props["node.target"];
    return direct !== undefined && direct !== null && String(direct) !== "" ? String(direct) : Audio.streamTargetName(stream);
  }

  function streamTargetsNode(stream, node) {
    const target = streamRouteTarget(stream);
    if (target === "") {
      const fallback = deviceDefault(streamKind(stream));
      return !!(fallback && fallback.name === node.name);
    }
    const serial = node.properties ? node.properties["object.serial"] : undefined;
    return target === node.name || (serial !== undefined && String(serial) === target);
  }

  function nodeHasStreamSignal(kind, node) {
    if (!node) return false;
    for (let i = 0; i < streams.length; i++) {
      const stream = streams[i];
      if (streamKind(stream) !== kind) continue;
      if (streamProps(stream)["application.name"] === "Quickshell Peak Detect") continue;
      if (!Audio.streamActive(stream)) continue;
      if (streamTargetsNode(stream, node)) return true;
    }
    return false;
  }

  function captureSnapshot(kind) {
    const list = deviceList(kind);
    const current = deviceDefault(kind);
    const pinned = devicePins(kind);
    const sticky = [];
    for (let i = 0; i < list.length; i++) {
      const name = list[i].name;
      if ((current && name === current.name) || pinned.indexOf(name) >= 0) sticky.push(name);
    }
    return sticky;
  }

  function capture() {
    outputSticky = captureSnapshot("output");
    inputSticky = captureSnapshot("input");
  }

  function deviceLabel(entry) {
    if (!entry) return "";
    if (entry.node) return Aliases.displayName(entry.node);
    return Aliases.aliasFor(entry.name) || entry.name;
  }

  function devicePriority(kind, name) {
    const index = (kind === "output" ? Priority.outputs : Priority.inputs).indexOf(name);
    return index < 0 ? 100000 : index;
  }

  function isLoopbackSource(node) {
    return !!(node && node.properties && node.properties["node.link-group"]);
  }

  function deviceEntries(kind) {
    const list = deviceList(kind);
    const current = deviceDefault(kind);
    const pinned = devicePins(kind);
    const sticky = kind === "output" ? outputSticky : inputSticky;
    const remembered = kind === "output" ? Priority.outputs : Priority.inputs;
    const rows = [];
    const seen = {};
    for (let i = 0; i < list.length; i++) {
      const node = list[i];
      const isCurrent = !!(current && node.name === current.name);
      const signal = nodeHasStreamSignal(kind, node);
      const dormant = kind === "input" && isLoopbackSource(node) && !signal;
      seen[node.name] = true;
      rows.push({
        node: node,
        name: node.name,
        present: true,
        current: isCurrent,
        pinned: pinned.indexOf(node.name) >= 0,
        sticky: sticky.indexOf(node.name) >= 0,
        dormant: dormant,
        monitored: kind === "output" ? signal : !dormant
      });
    }
    for (let i = 0; i < remembered.length; i++) {
      const name = remembered[i];
      if (seen[name]) continue;
      rows.push({
        node: null,
        name: name,
        present: false,
        current: false,
        pinned: pinned.indexOf(name) >= 0,
        sticky: false,
        dormant: false,
        monitored: false
      });
    }
    rows.sort((a, b) => {
      const pa = devicePriority(kind, a.name);
      const pb = devicePriority(kind, b.name);
      if (pa !== pb) return pa - pb;
      if (a.present !== b.present) return a.present ? -1 : 1;
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
    });
    return rows;
  }

  function reorderDevice(kind, name, target) {
    if (Priority.reorder(kind, name, target)) Audio.applyPriority();
  }

  function setDefault(kind, node) {
    if (kind === "output") Pipewire.preferredDefaultAudioSink = node;
    else Pipewire.preferredDefaultAudioSource = node;
    Audio.refreshDefaults();
    if (!node) return;
    if (kind === "output") Audio.deferredSink = node;
    else Audio.deferredSource = node;
  }

  function pruneSticky(kind) {
    const sticky = (kind === "output" ? outputSticky : inputSticky).slice();
    const current = deviceDefault(kind);
    const pinned = devicePins(kind);
    const kept = [];
    for (let i = 0; i < sticky.length; i++) {
      const name = sticky[i];
      if ((current && name === current.name) || pinned.indexOf(name) >= 0) kept.push(name);
    }
    if (kept.length === sticky.length) return;
    if (kind === "output") outputSticky = kept;
    else inputSticky = kept;
  }

  function togglePin(kind, name) {
    Pins.toggle(kind, name);
    if (!Pins.isPinned(kind, name)) {
      const present = deviceList(kind);
      let found = false;
      for (let i = 0; i < present.length; i++) if (present[i].name === name) {
        found = true;
        break;
      }
      if (!found) Priority.remove(kind, name);
    }
    const sticky = (kind === "output" ? outputSticky : inputSticky).slice();
    const at = sticky.indexOf(name);
    if (Pins.isPinned(kind, name)) {
      if (at < 0) sticky.push(name);
    } else if (at >= 0) {
      sticky.splice(at, 1);
    }
    if (kind === "output") outputSticky = sticky;
    else inputSticky = sticky;
  }

  function streamKind(stream) {
    return mediaClass(stream) === "Stream/Input/Audio" ? "input" : "output";
  }

  function streamProps(stream) {
    return stream && stream.properties ? stream.properties : {};
  }

  function streamFingerprint(stream) {
    const props = streamProps(stream);
    const app = props["application.name"] ? props["application.name"] : stream.name;
    return [app, props["media.name"] ? props["media.name"] : "", streamKind(stream)].join("|");
  }

  function streamKey(stream) {
    const props = streamProps(stream);
    return streamFingerprint(stream) + "|" + (props["object.serial"] ? props["object.serial"] : stream.id);
  }

  function routeTargets(kind) {
    return kind === "output" ? sinks : sources;
  }

  function streamTarget(stream) {
    const name = Audio.streamTargetName(stream);
    if (!name) return null;
    const list = routeTargets(streamKind(stream));
    for (let i = 0; i < list.length; i++) if (list[i].name === name) return list[i];
    return null;
  }

  function targetName(node) {
    return node ? Aliases.displayName(node) : "Default";
  }

  function streamName(stream) {
    if (!stream) return "";
    const media = streamProps(stream)["media.name"];
    return media && media.length > 0 ? media : stream.name;
  }

  function appName(stream) {
    const app = stream ? streamProps(stream)["application.name"] : "";
    return app && app.length > 0 ? app : stream.name;
  }

  function iconCandidates(stream) {
    const props = streamProps(stream);
    const cls = Hypr.classFor([appName(stream), props["application.icon-name"], props["application.process.binary"], stream.name]);
    const icon = String(props["application.icon-name"] ? props["application.icon-name"] : "").replace(/-symbolic$/, "");
    return [cls, icon, props["application.process.binary"], appName(stream)];
  }

  function resolveIcon(value) {
    if (!value) return "";
    const kept = root.iconCache[value];
    if (kept !== undefined) return kept;
    const resolved = AppIcons.resolve(value);
    if (!resolved) return "";
    if (resolved !== value) {
      root.iconCache[value] = resolved;
      return resolved;
    }
    const good = Quickshell.iconPath(resolved, "") !== "" ? resolved : "";
    if (good !== "") root.iconCache[value] = good;
    return good;
  }

  function streamIcon(stream) {
    const candidates = iconCandidates(stream);
    for (let i = 0; i < candidates.length; i++) {
      const good = resolveIcon(candidates[i]);
      if (good) return good;
    }
    for (let i = 0; i < candidates.length; i++) if (candidates[i]) return candidates[i];
    return "application-x-executable";
  }

  function effectiveExpanded(name) {
    const override = root.appOverrides[name];
    return override === undefined ? root.appExpanded : override;
  }

  function toggleApp(name) {
    const next = !root.effectiveExpanded(name);
    const map = {};
    for (const key in root.appOverrides) map[key] = root.appOverrides[key];
    if (next === root.appExpanded) delete map[name];
    else map[name] = next;
    root.appOverrides = map;
  }

  function toggleAppPin(name) {
    const wasPinned = Pins.isAppPinned(name);
    Pins.toggleApp(name);
    if (wasPinned) AppIconCache.forget(name);
  }

  function hasVisibleAppCards() {
    for (let i = 0; i < root.appSnapshot.length; i++) {
      const group = root.appSnapshot[i];
      if (!group) continue;
      if ((group.totalCount || 0) === 0) {
        if (root.appExpanded && Pins.isAppPinned(group.name)) return true;
        continue;
      }
      if (root.effectiveExpanded(group.name)) return true;
      if (Pins.isAppPinned(group.name)) return true;
      if ((group.pinnedCount || 0) > 0) return true;
      if ((group.activeCount || 0) > 0) return true;
    }
    return false;
  }

  function activeCount(list) {
    let count = 0;
    for (let i = 0; i < list.length; i++) if (Audio.streamActive(list[i].node)) count += 1;
    return count;
  }

  function pinnedCount(list) {
    let count = 0;
    for (let i = 0; i < list.length; i++) if (Pins.isStreamPinned(list[i].key)) count += 1;
    return count;
  }

  function sortStreamRows(list) {
    list.sort((a, b) => {
      const aPinned = Pins.isStreamPinned(a.key) ? 0 : 1;
      const bPinned = Pins.isStreamPinned(b.key) ? 0 : 1;
      if (aPinned !== bPinned) return aPinned - bPinned;
      const aActive = Audio.streamActive(a.node) ? 0 : 1;
      const bActive = Audio.streamActive(b.node) ? 0 : 1;
      if (aActive !== bActive) return aActive - bActive;
      if (aActive === 1) {
        const aLast = Audio.lastActiveMs(a.node);
        const bLast = Audio.lastActiveMs(b.node);
        if (aLast !== bLast) return bLast - aLast;
      }
      const aAge = Number(streamSerial(a.node));
      const bAge = Number(streamSerial(b.node));
      if (aAge !== bAge) return aAge - bAge;
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
    });
  }

  function assignViewKeys(list) {
    for (let i = 0; i < list.length; i++) list[i].viewKey = streamSerial(list[i].node);
  }

  function computeActiveSig() {
    const parts = [];
    for (let i = 0; i < streams.length; i++) {
      const stream = streams[i];
      const key = streamKey(stream);
      parts.push(key + "=" + (Audio.streamActive(stream) ? "1" : "0") + (Pins.isStreamPinned(key) ? "p" : "") + streamIcon(stream) + "|" + streamName(stream));
    }
    parts.sort();
    return parts.join(";");
  }

  function requestAppsRefresh() {
    if (!root.open) return;
    if (root.routeStream) root.closeRoute();
    if (!appsCap.running) appsCap.start();
    appsDebounce.restart();
  }

  ListModel {
    id: appModel
  }

  function appCards() {
    const out = [];
    const kids = appList.contentItem.children;
    for (let i = 0; i < kids.length; i++) {
      const child = kids[i];
      if (child && child.objectName === "appCard" && child.card) out.push(child.card);
    }
    return out;
  }

  function syncApps() {
    const groups = root.appSnapshot;
    for (let i = appModel.count - 1; i >= 0; i--) {
      const name = appModel.get(i).name;
      let found = false;
      for (let j = 0; j < groups.length; j++) if (groups[j].name === name) {
        found = true;
        break;
      }
      if (!found) appModel.remove(i);
    }
    for (let j = 0; j < groups.length; j++) {
      const item = groups[j];
      let at = -1;
      for (let i = 0; i < appModel.count; i++) if (appModel.get(i).name === item.name) {
        at = i;
        break;
      }
      if (at < 0) appModel.insert(j, { name: item.name, groupData: item });
      else {
        if (at !== j) appModel.move(at, j, 1);
        appModel.setProperty(j, "groupData", item);
      }
    }
  }

  function appRows(group) {
    const rows = [];
    for (let i = 0; i < group.inputs.length; i++) rows.push(group.inputs[i]);
    if (group.inputs.length > 0 && group.outputs.length > 0) rows.push({ separator: true });
    for (let i = 0; i < group.outputs.length; i++) rows.push(group.outputs[i]);
    return rows;
  }

  function groupIconFor(group) {
    const lists = [group.inputs, group.outputs];
    let fallback = "";
    for (let l = 0; l < lists.length; l++) {
      for (let i = 0; i < lists[l].length; i++) {
        const candidates = iconCandidates(lists[l][i].node);
        for (let c = 0; c < candidates.length; c++) {
          const good = resolveIcon(candidates[c]);
          if (good) return good;
        }
        if (!fallback && candidates.length > 0 && candidates[0]) fallback = candidates[0];
      }
    }
    if (fallback === "") fallback = AppIconCache.cached(group.name) || resolveIcon(group.name);
    return fallback !== "" ? fallback : "application-x-executable";
  }

  function streamSerial(stream) {
    const props = streamProps(stream);
    return props["object.serial"] ? String(props["object.serial"]) : String(stream.id);
  }

  function genericStreamName(name, stream) {
    if (!name) return true;
    if (name === "AudioStream" || name === "Playback Stream" || name === "Capture Stream" || name === "Record Stream") return true;
    return name === stream.name;
  }

  function streamDisplayName(stream, names) {
    const live = streamName(stream);
    const serial = streamSerial(stream);
    if (!genericStreamName(live, stream)) {
      names[serial] = live;
      return live;
    }
    const kept = names[serial] !== undefined ? names[serial] : root.streamNameCache[serial];
    if (kept) {
      names[serial] = kept;
      return kept;
    }
    return live;
  }

  function captureApps() {
    const groups = [];
    const index = {};
    const names = {};
    for (let i = 0; i < streams.length; i++) {
      const stream = streams[i];
      if (streamProps(stream)["application.name"] === "Quickshell Peak Detect") continue;
      const name = appName(stream);
      if (index[name] === undefined) {
        const group = { name: name, icon: streamIcon(stream), inputs: [], outputs: [] };
        index[name] = group;
        groups.push(group);
      }
      const kind = streamKind(stream);
      const row = { node: stream, kind: kind, key: streamKey(stream), fingerprint: streamFingerprint(stream), name: streamDisplayName(stream, names) };
      if (kind === "input") index[name].inputs.push(row);
      else index[name].outputs.push(row);
    }
    for (let i = 0; i < Pins.apps.length; i++) {
      const name = Pins.apps[i];
      if (index[name] !== undefined) continue;
      const group = { name: name, icon: "", inputs: [], outputs: [] };
      index[name] = group;
      groups.push(group);
    }
    root.streamNameCache = names;
    for (let i = 0; i < groups.length; i++) {
      const group = groups[i];
      sortStreamRows(group.inputs);
      sortStreamRows(group.outputs);
      assignViewKeys(group.inputs);
      assignViewKeys(group.outputs);
      group.icon = groupIconFor(group);
      group.outputCount = group.outputs.length;
      group.inputCount = group.inputs.length;
      group.badge = group.inputCount > 0 ? group.outputCount + "/" + group.inputCount : String(group.outputCount);
      group.activeCount = activeCount(group.inputs) + activeCount(group.outputs);
      group.pinnedCount = pinnedCount(group.inputs) + pinnedCount(group.outputs);
      group.totalCount = group.outputCount + group.inputCount;
      if (group.totalCount > 0 && Pins.isAppPinned(group.name)) AppIconCache.remember(group.name, group.icon);
      group.rows = appRows(group);
    }
    groups.sort((a, b) => {
      const aApp = Pins.isAppPinned(a.name) ? 0 : 1;
      const bApp = Pins.isAppPinned(b.name) ? 0 : 1;
      if (aApp !== bApp) return aApp - bApp;
      if (aApp === 0) {
        const ai = Pins.apps.indexOf(a.name);
        const bi = Pins.apps.indexOf(b.name);
        if (ai !== bi) return ai - bi;
      }
      if (b.pinnedCount !== a.pinnedCount) return b.pinnedCount - a.pinnedCount;
      if (b.activeCount !== a.activeCount) return b.activeCount - a.activeCount;
      if (b.totalCount !== a.totalCount) return b.totalCount - a.totalCount;
      const aName = a.name.toLowerCase();
      const bName = b.name.toLowerCase();
      return aName < bName ? -1 : aName > bName ? 1 : 0;
    });
    const kept = {};
    for (const key in root.appOverrides) {
      if (index[key] !== undefined) kept[key] = root.appOverrides[key];
    }
    root.appOverrides = kept;
    root.appSnapshot = groups;
    root.activeSig = root.computeActiveSig();
    root.syncApps();
  }

  function routeRows() {
    if (!root.routeStream) return [];
    const entries = root.deviceEntries(streamKind(root.routeStream));
    const list = [];
    for (let i = 0; i < entries.length; i++) if (entries[i].node) list.push(entries[i].node);
    const rows = [{ node: null, separator: false }];
    if (list.length > 0) rows.push({ node: null, separator: true });
    for (let i = 0; i < list.length; i++) rows.push({ node: list[i], separator: false });
    return rows;
  }

  function resolveRouteStream(key, node) {
    if (node) return node;
    const parts = key.split("|");
    const prefix = parts.slice(0, parts.length - 1).join("|");
    if (prefix === "") return null;
    for (let i = 0; i < streams.length; i++) if (streamKey(streams[i]).indexOf(prefix + "|") === 0) return streams[i];
    return null;
  }

  function openRoute(stream, anchor) {
    if (!stream) return;
    if (root.routeStream === stream) {
      closeRoute();
      return;
    }
    if (root.routeDismissed === stream && Date.now() - root.routeClosedAt < 250) {
      root.routeDismissed = null;
      return;
    }
    root.routeDismissed = null;
    root.routeStream = stream;
    const offset = Math.round(4 * Theme.scale);
    const reference = routePopup.parent;
    const anchorX = anchor.width - routePopup.width;
    const anchorY = anchor.height + offset;
    const point = reference ? anchor.mapToItem(reference, anchorX, anchorY) : anchor.mapToItem(null, anchorX, anchorY);
    routePopup.x = point.x;
    routePopup.y = point.y;
    routePopup.open();
  }

  function closeRoute() {
    root.routeStream = null;
    routePopup.close();
  }

  function routeTo(node) {
    const stream = root.routeStream;
    if (!stream) return;
    if (node) Quickshell.execDetached(["pw-metadata", "-n", "default", String(stream.id), "target.object", node.name, "Spa:String"]);
    else Quickshell.execDetached(["pw-metadata", "-n", "default", "-d", String(stream.id), "target.object"]);
    Audio.setStreamTarget(stream, node ? node.name : "");
    closeRoute();
  }

  function cancelEdits() {
    outputCard.cancelEdit();
    inputCard.cancelEdit();
    const cards = root.appCards();
    for (let i = 0; i < cards.length; i++) cards[i].cancelPercentEdits();
    root.appPercentEditor = null;
  }

  function refreshAppPercentEditor() {
    let found = null;
    const cards = root.appCards();
    for (let i = 0; i < cards.length; i++) {
      const editor = cards[i].activePercentEditor;
      if (editor) {
        found = editor;
        break;
      }
    }
    root.appPercentEditor = found;
  }

  readonly property var activeNameEditor: outputCard.activeEditor ? outputCard.activeEditor : inputCard.activeEditor
  readonly property var activeDevicePercentEditor: outputCard.activePercentEditor ? outputCard.activePercentEditor : inputCard.activePercentEditor
  property var appPercentEditor: null
  readonly property var activePercentEditor: root.activeDevicePercentEditor ? root.activeDevicePercentEditor : root.appPercentEditor
  readonly property var activeEditor: root.activeNameEditor ? root.activeNameEditor : root.activePercentEditor

  function testFindDevicePercentEditor(kind, displayText) {
    const entry = root.testFindEntry(kind, displayText);
    if (!entry || !entry.node) return null;
    const card = kind === "output" ? outputCard : inputCard;
    return card.findPercentEditor(entry.node.name);
  }

  function testFindAppPercentEditor(appName, rowIndex) {
    const cards = root.appCards();
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (card && card.group && card.group.name === appName) return card.percentEditorAt(rowIndex);
    }
    return null;
  }

  function testPercentRect(editor) {
    if (!editor) return null;
    const point = editor.mapToItem(null, 0, 0);
    if (!point) return null;
    return { x: point.x, y: point.y, width: editor.width, height: editor.height, editing: editor.editing };
  }

  function testDevicePercentRect(kind, displayText) {
    return root.testPercentRect(root.testFindDevicePercentEditor(kind, displayText));
  }

  function testAppPercentRect(appName, rowIndex) {
    return root.testPercentRect(root.testFindAppPercentEditor(appName, rowIndex));
  }

  function testFindEditor(displayText) {
    const output = outputCard.findNameEditor(displayText);
    return output !== null ? output : inputCard.findNameEditor(displayText);
  }

  function testNodeName(displayText) {
    const key = outputCard.testNodeName(displayText);
    return key !== "" ? key : inputCard.testNodeName(displayText);
  }

  function testDeviceNames() {
    return {
      outputs: root.deviceEntries("output").map((entry) => root.deviceLabel(entry)),
      inputs: root.deviceEntries("input").map((entry) => root.deviceLabel(entry))
    };
  }

  function testPriorityOrder(kind) {
    return (kind === "output" ? Priority.outputs : Priority.inputs).slice();
  }

  function testPriorityMove(kind, name, target) {
    root.reorderDevice(kind, name, target);
    return true;
  }

  function testEditorRect(displayText) {
    const editor = root.testFindEditor(displayText);
    if (!editor) return null;
    const point = editor.mapToItem(null, 0, 0);
    if (!point) return null;
    return { x: point.x, y: point.y, width: editor.width, height: editor.height, editing: editor.editing };
  }

  function testCurrentDevice(kind) {
    const list = root.deviceEntries(kind);
    for (let i = 0; i < list.length; i++) if (list[i].current) return root.deviceLabel(list[i]);
    return "";
  }

  function testAppNames() {
    return root.appSnapshot.map((group) => group.name);
  }

  function testAppOrder() {
    return Pins.apps.slice();
  }

  function testMoveApp(name, target) {
    const moved = Pins.reorderApp(name, target);
    if (root.open) root.captureApps();
    return moved;
  }

  function testClearAlias(nodeName) {
    Aliases.setAlias(nodeName, "");
    return true;
  }

  function testToggleStreamPin(app, rowIndex) {
    const cards = root.appCards();
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (card && card.group && card.group.name === app) {
        const rows = card.group.rows;
        let seen = -1;
        for (let j = 0; j < rows.length; j++) {
          if (rows[j].separator === true) continue;
          seen += 1;
          if (seen === rowIndex) {
            Pins.toggleStream(rows[j].key);
            return true;
          }
        }
        return false;
      }
    }
    return false;
  }

  function testPinApp(app) {
    const cards = root.appCards();
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (card && card.group && card.group.name === app) {
        root.toggleAppPin(app);
        return true;
      }
    }
    return false;
  }

  function testToggleSection(section) {
    root.cancelEdits();
    if (section === "output") root.outputExpanded = !root.outputExpanded;    else if (section === "input") root.inputExpanded = !root.inputExpanded;
    else if (section === "apps") root.appExpanded = !root.appExpanded;
    else return false;
    return true;
  }

  function testSetSection(section, state) {
    root.cancelEdits();
    const value = state === true;
    if (section === "output") root.outputExpanded = value;
    else if (section === "input") root.inputExpanded = value;
    else if (section === "apps") root.appExpanded = value;
    else return false;
    return true;
  }

  function testSetApp(app, state) {
    const value = state === true;
    const groups = root.appSnapshot;
    let found = false;
    for (let i = 0; i < groups.length; i++) if (groups[i].name === app) {
      found = true;
      break;
    }
    if (!found) return false;
    const map = {};
    for (const key in root.appOverrides) map[key] = root.appOverrides[key];
    if (value === root.appExpanded) delete map[app];
    else map[app] = value;
    root.appOverrides = map;
    return true;
  }

  function testAppRows(app) {
    const cards = root.appCards();
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (card && card.group && card.group.name === app) {
        const rows = card.group.rows;
        const out = [];
        for (let j = 0; j < rows.length; j++) {
          const row = rows[j];
          if (row.separator === true) out.push({ separator: true, shown: card.anyInputShown && card.anyOutputShown });
          else out.push({ separator: false, key: row.key, label: row.name, kind: row.kind, pinned: Pins.isStreamPinned(row.key), shown: card.streamRowShown(row.key, row.node) });
        }
        return out;
      }
    }
    return null;
  }

  function testRouteStream(app, rowIndex, targetText) {
    const cards = root.appCards();
    let stream = null;
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      if (card && card.group && card.group.name === app) {
        const rows = card.group.rows;
        let seen = -1;
        for (let j = 0; j < rows.length; j++) {
          if (rows[j].separator === true) continue;
          seen += 1;
          if (seen === rowIndex) {
            stream = rows[j].node;
            break;
          }
        }
      }
    }
    if (!stream) return false;
    const list = routeTargets(streamKind(stream));
    let node = null;
    if (targetText && targetText !== "Default") {
      for (let i = 0; i < list.length; i++) {
        if (Aliases.displayName(list[i]) === targetText || list[i].name === targetText) {
          node = list[i];
          break;
        }
      }
      if (!node) return false;
    }
    if (node) Quickshell.execDetached(["pw-metadata", "-n", "default", String(stream.id), "target.object", node.name, "Spa:String"]);
    else Quickshell.execDetached(["pw-metadata", "-n", "default", "-d", String(stream.id), "target.object"]);
    Audio.setStreamTarget(stream, node ? node.name : "");
    return true;
  }

  function testFindEntry(kind, displayText) {
    const list = root.deviceEntries(kind);
    for (let i = 0; i < list.length; i++) if (root.deviceLabel(list[i]) === displayText) return list[i];
    return null;
  }

  function testPinDevice(kind, displayText) {
    const entry = root.testFindEntry(kind, displayText);
    if (!entry) return false;
    root.togglePin(kind, entry.name);
    return true;
  }

  function testDefaultDevice(kind, displayText) {
    const entry = root.testFindEntry(kind, displayText);
    if (!entry) return false;
    root.setDefault(kind, entry.node);
    return true;
  }

  cancelItem: root.activeEditor
  onCancelRequested: root.cancelEdits()

  onOpened: {
    root.capture();
    root.captureApps();
    Audio.refreshStreamTargets();
    root.measuring = true;
    measureTimer.attempts = 0;
    measureTimer.restart();
    root.routeDismissed = null;
    root.closeRoute();
  }

  onStreamsChanged: root.requestAppsRefresh()

  onDefaultSinkChanged: root.pruneSticky("output")
  onDefaultSourceChanged: root.pruneSticky("input")

  Connections {
    target: Pins

    function onStreamsChanged() {
      if (root.open) root.captureApps();
    }

    function onAppsChanged() {
      if (root.open) root.captureApps();
    }
  }

  Timer {
    id: appsDebounce

    interval: 800
    running: false
    repeat: false
    onTriggered: {
      appsCap.stop();
      root.captureApps();
    }
  }

  Timer {
    id: appsCap

    interval: 2000
    running: false
    repeat: false
    onTriggered: {
      appsDebounce.stop();
      root.captureApps();
    }
  }

  Timer {
    id: activePoll

    interval: 2000
    running: root.open
    repeat: true
    onTriggered: {
      if (root.computeActiveSig() !== root.activeSig) root.requestAppsRefresh();
    }
  }

  onScrolled: root.closeRoute()

  Timer {
    id: measureTimer

    interval: 60
    running: false
    repeat: false
    property int attempts: 0

    onTriggered: {
      measureTimer.attempts += 1;
      if (measureTimer.attempts < 8 && (root.maxCardHeight <= 0 || root.viewportHeight <= 0)) {
        measureTimer.restart();
        return;
      }
      root.measuring = false;
    }
  }

  PwObjectTracker {
    objects: {
      const out = [];
      for (let i = 0; i < nodes.length; i++) if (nodes[i].audio) out.push(nodes[i]);
      return out;
    }
  }

  SectionHeader {
    label: "Output"

    IconButton {
      size: Math.round(20 * Theme.scale)
      name: root.outputExpanded ? "chevron-up" : "chevron-down"
      iconColor: Theme.overlay
      onClicked: {
        root.cancelEdits();
        root.outputExpanded = !root.outputExpanded;
      }
    }
  }

  AudioDeviceCard {
    id: outputCard

    width: parent.width
    kind: "output"
    devices: root.deviceEntries("output")
    showAll: root.outputExpanded
    maxVolume: Audio.maxVolume
    onSetDefault: (node) => root.setDefault("output", node)
    onTogglePin: (name) => root.togglePin("output", name)
    onWheeled: (node, angleDelta) => Audio.wheelAdjust(node, angleDelta)
    onReordered: (name, target) => root.reorderDevice("output", name, target)
  }

  SectionHeader {
    label: "Input"

    IconButton {
      size: Math.round(20 * Theme.scale)
      name: root.inputExpanded ? "chevron-up" : "chevron-down"
      iconColor: Theme.overlay
      onClicked: {
        root.cancelEdits();
        root.inputExpanded = !root.inputExpanded;
      }
    }
  }

  AudioDeviceCard {
    id: inputCard

    width: parent.width
    kind: "input"
    devices: root.deviceEntries("input")
    showAll: root.inputExpanded
    maxVolume: Audio.maxVolume
    onSetDefault: (node) => root.setDefault("input", node)
    onTogglePin: (name) => root.togglePin("input", name)
    onWheeled: (node, angleDelta) => Audio.wheelAdjust(node, angleDelta)
    onReordered: (name, target) => root.reorderDevice("input", name, target)
  }

  SectionHeader {
    label: "Application Volumes"

    IconButton {
      size: Math.round(20 * Theme.scale)
      name: root.appExpanded ? "chevron-up" : "chevron-down"
      iconColor: Theme.overlay
      onClicked: {
        root.cancelEdits();
        root.appExpanded = !root.appExpanded;
      }
    }
  }

  Item {
    width: parent.width
    height: appColumn.height

    Column {
      id: appColumn

      width: parent.width
      spacing: 0

      Item {
        width: parent.width
        height: appList.contentHeight

        DragReorder {
          id: appDragger

          listView: appList
          model: appModel
          keyRole: "name"
          rowObjectName: "appCard"
          maxTarget: Pins.apps.length - 1
          onMoved: (key, target) => Pins.reorderApp(key, target)
        }

        ListView {
          id: appList

          anchors.fill: parent
          interactive: false
          focus: false
          clip: !appDragger.dragging
          model: appModel
          spacing: Theme.gap
          cacheBuffer: 100000
          move: Transition { enabled: !root.measuring && !appDragger.suppressMove; NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }
          displaced: Transition { enabled: !root.measuring && !appDragger.suppressMove; NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }

          delegate: Item {
            id: appDelegate

            objectName: "appCard"

            readonly property string dragKey: groupData.name
            readonly property var card: appCard

            width: appList.width
            height: appCard.height
            z: appCard.dragging || appCard.settling ? 2 : 0

            AppGroupCard {
              id: appCard

              width: parent.width
              group: groupData
              expanded: root.effectiveExpanded(group.name)
              appPinned: Pins.isAppPinned(group.name)
              sectionVisible: root.appExpanded
              animate: !root.measuring
              routeStream: root.routeStream
              targetFor: (node) => root.targetName(root.streamTarget(node))
              maxVolume: Audio.maxVolume
              dragging: appDragger.dragging && appDragger.dragKey === groupData.name
              settling: appDragger.settling && appDragger.settleKey === groupData.name
              dragDelta: appDragger.dragDelta
              dropShift: appDragger.dropShift
              previewShift: appDragger.previewForKey(groupData.name)
              snapPreview: appDragger.snapPreview
              onToggleExpanded: root.toggleApp(group.name)
              onAppPinToggled: root.toggleAppPin(group.name)
              onPinToggled: (key) => Pins.toggleStream(key)
              onRoutePressed: (key, node, anchor) => root.openRoute(root.resolveRouteStream(key, node), anchor)
              onWheeled: (node, angleDelta) => Audio.wheelAdjust(node, angleDelta)
              onPercentEditing: (editor) => {
                if (editor) root.appPercentEditor = editor;
                else root.refreshAppPercentEditor();
              }
              onDragStarted: (key, sceneY) => appDragger.begin(key, sceneY)
              onDragMoved: (sceneY) => appDragger.update(sceneY)
              onDragEnded: () => appDragger.end()
              onDragCancelled: () => appDragger.cancel()
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: appDragger.dragging
          acceptedButtons: Qt.RightButton
          z: 10
          onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) appDragger.cancel();
          }
        }
      }

      Rectangle {
        id: appPlaceholder

        width: parent.width
        height: !root.hasVisibleAppCards() ? Math.round(76 * Theme.scale) + Theme.gap : 0
        radius: Theme.rowRadius
        color: Theme.surface
        antialiasing: true
        visible: !root.hasVisibleAppCards() || appPlaceholder.height > 0.5
        clip: true
        opacity: !root.hasVisibleAppCards() ? 1 : 0

        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Column {
        anchors.centerIn: parent
        spacing: Math.round(8 * Theme.scale)

        Icon {
          anchors.horizontalCenter: parent.horizontalCenter
          name: "volume-off"
          color: Theme.overlay
          font.pixelSize: Math.round(22 * Theme.scale)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "No apps are playing or recording audio"
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }
      }
      }
    }
  }

  Popup {
    id: routePopup

    popupType: Popup.Item
    modal: false
    padding: Math.round(3 * Theme.scale)
    width: Math.round(176 * Theme.scale)
    height: routeColumn.implicitHeight + Math.round(6 * Theme.scale)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onClosed: {
      root.routeDismissed = root.routeStream;
      root.routeClosedAt = Date.now();
      root.routeStream = null;
    }

    background: Rectangle {
      color: Theme.surfaceHigh
      radius: Theme.rowRadius
      border.width: 1
      border.color: Theme.surfaceHigher
      antialiasing: true
    }

    contentItem: Column {
      id: routeColumn

      spacing: Math.round(1 * Theme.scale)

      Repeater {
        model: root.routeRows()

        delegate: Item {
          id: routeOption

          required property var modelData

          readonly property bool separator: modelData.separator === true
          readonly property var optionNode: modelData.node

          width: routeColumn.width
          height: separator ? Math.round(1 * Theme.scale) : Math.round(22 * Theme.scale)

          Rectangle {
            anchors.fill: parent
            visible: !routeOption.separator
            radius: Math.round(6 * Theme.scale)
            color: optionMouse.containsMouse ? Theme.surfaceHigher : "transparent"
            antialiasing: true
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(1 * Theme.scale)
            visible: routeOption.separator
            color: Theme.surfaceHigher
          }

          Item {
            id: optionCheck

            anchors.left: parent.left
            anchors.leftMargin: Math.round(6 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(16 * Theme.scale)
            height: width

            Icon {
              anchors.centerIn: parent
              visible: !routeOption.separator && (routeOption.optionNode ? root.streamTarget(root.routeStream) === routeOption.optionNode : root.streamTarget(root.routeStream) === null)
              name: "check"
              color: Theme.primary
              font.pixelSize: Math.round(9 * Theme.scale)
            }
          }

          Text {
            anchors.left: optionCheck.right
            anchors.leftMargin: Math.round(4 * Theme.scale)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            visible: !routeOption.separator
            text: root.targetName(routeOption.optionNode)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(9 * Theme.scale)
            elide: Text.ElideRight
          }

          MouseArea {
            id: optionMouse

            anchors.fill: parent
            enabled: !routeOption.separator
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.routeTo(routeOption.optionNode)
          }
        }
      }
    }
  }
}
