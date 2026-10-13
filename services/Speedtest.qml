pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/wifi-speedtest.json"

  property bool running: false
  property string phase: ""
  property double down: -1
  property double up: -1
  property string error: ""
  property string target: ""
  property string iface: ""
  property bool cancelled: false
  property int serverId: -1
  property double baseline: -1
  property double listAt: 0
  property bool pinnedRun: false
  property bool retried: false
  property int resultId: -1

  function toMbps(bytesPerSec) {
    return bytesPerSec / 125000;
  }

  function text(value) {
    return value < 0 ? "--" : value.toFixed(1) + "Mb/s";
  }

  function statusText() {
    if (root.phase === "ping") return "Ping...";
    return "Starting...";
  }

  function visibleFor(name) {
    if (name === "" || root.target !== name) return false;
    return root.running || root.down >= 0 || root.up >= 0 || root.error !== "";
  }

  function runSpeedtest(pinned) {
    speedProc.command = ["speedtest", "-f", "jsonl", "--progress-update-interval=100"].concat(pinned && root.serverId > 0 ? ["-s", String(root.serverId)] : []).concat(root.iface !== "" ? ["-I", root.iface] : []);
    root.pinnedRun = pinned && root.serverId > 0;
    speedProc.running = true;
  }

  function preload() {
    if (speedProc.running || listProc.running) return false;
    if (Date.now() - root.listAt < 60000) return true;
    root.listAt = Date.now();
    listProc.running = true;
    return true;
  }

  function handleList(payload) {
    let obj = null;
    try {
      obj = JSON.parse(payload);
    } catch (e) {
      return;
    }
    if (!obj || obj.type !== "serverList" || !obj.servers || obj.servers.length === 0) return;
    const id = Math.floor(Number(obj.servers[0].id));
    if (id > 0 && id !== root.serverId) {
      root.serverId = id;
      root.save();
    }
  }

  function save() {
    const data = JSON.stringify({ serverId: root.serverId, baseline: root.baseline });
    const escaped = data.replace(/'/g, "'\\''");
    Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$(dirname " + file + ")\"; printf '%s' '" + escaped + "' > " + file]);
  }

  function toggle(name, iface) {
    if (!name) return false;
    if (speedProc.running) {
      root.cancelled = true;
      speedProc.running = false;
      return true;
    }
    root.target = name;
    root.iface = iface ? iface : "";
    root.phase = "";
    root.down = -1;
    root.up = -1;
    root.error = "";
    root.cancelled = false;
    root.running = true;
    root.retried = false;
    root.resultId = -1;
    root.runSpeedtest(true);
    return true;
  }

  function handleLine(line) {
    let obj = null;
    try {
      obj = JSON.parse(line);
    } catch (e) {
      return;
    }
    if (!obj || !obj.type) return;
    if (obj.type === "download" && obj.download && obj.download.bandwidth >= 0) {
      root.phase = "down";
      root.down = root.toMbps(obj.download.bandwidth);
    } else if (obj.type === "upload" && obj.upload && obj.upload.bandwidth >= 0) {
      root.phase = "up";
      root.up = root.toMbps(obj.upload.bandwidth);
    } else if (obj.type === "ping") {
      root.phase = "ping";
    } else if (obj.type === "result") {
      if (obj.download) root.down = root.toMbps(obj.download.bandwidth);
      if (obj.upload) root.up = root.toMbps(obj.upload.bandwidth);
      if (obj.server) {
        const id = Math.floor(Number(obj.server.id));
        if (id > 0) root.resultId = id;
      }
    }
  }

  function finish(code) {
    if (root.cancelled) {
      root.running = false;
      root.cancelled = false;
      root.phase = "";
      return;
    }
    const failed = code !== 0 && root.down < 0 && root.up < 0;
    const suspect = code === 0 && root.baseline > 0 && root.down >= 0 && root.down < root.baseline * 0.7;
    if (root.pinnedRun && !root.retried && (failed || suspect)) {
      root.retried = true;
      root.pinnedRun = false;
      if (!failed) root.baseline = root.down;
      root.phase = "";
      root.down = -1;
      root.up = -1;
      root.error = "";
      root.resultId = -1;
      root.save();
      root.runSpeedtest(false);
      return;
    }
    root.running = false;
    if (failed) root.error = "Failed";
    else if (root.down >= 0 && root.down > root.baseline) root.baseline = root.down;
    if (root.resultId > 0 && !root.pinnedRun && root.down >= 0) root.serverId = root.resultId;
    if (code === 0) root.save();
    root.phase = "";
  }

  function mock(target, phase, down, up) {
    if (!target) return false;
    root.target = target;
    root.phase = phase;
    root.down = down;
    root.up = up;
    root.error = "";
    root.running = phase !== "" && phase !== "done";
    return true;
  }

  function state() {
    return { running: root.running, phase: root.phase, down: root.down, up: root.up, error: root.error, target: root.target, server: root.serverId, iface: root.iface };
  }

  Process {
    id: speedProc

    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: (data) => root.handleLine(data)
    }
    onExited: (code) => root.finish(code)
  }

  Process {
    id: listProc

    running: false
    command: ["speedtest", "-L", "-f", "json"]
    stdout: StdioCollector {
      onStreamFinished: root.handleList(text)
    }
  }

  Process {
    id: readProc

    running: true
    command: ["bash", "-lc", "cat " + root.file + " 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text);
          if (data.serverId > 0) root.serverId = Math.floor(Number(data.serverId));
          if (data.baseline > 0) root.baseline = Number(data.baseline);
        } catch (e) {
        }
      }
    }
  }
}
