pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string directory: "/tmp/screenshot"

  function target(geometry, output) {
    if (output) return "-o " + output;
    if (geometry) return "-g '" + geometry + "'";
    return "";
  }

  function grab(geometry, output) {
    run("mkdir -p " + directory + "; f=" + directory + "/$(date +%Y%m%d-%H%M%S).png; grim " + target(geometry, output) + " \"$f\" && wl-copy < \"$f\"");
  }

  function region() {
    run("mkdir -p " + directory + "; g=$(slurp) || exit 0; f=" + directory + "/$(date +%Y%m%d-%H%M%S).png; grim -g \"$g\" \"$f\" && wl-copy < \"$f\"");
  }

  function activeWindow() {
    windowProc.running = true;
  }

  function focusedMonitor() {
    monitorProc.running = true;
  }

  function allMonitors() {
    grab("", "");
  }

  function annotate() {
    run("f=$(ls -t " + directory + "/*.png 2>/dev/null | head -1); [ -n \"$f\" ] && satty --filename \"$f\" --output-filename \"$f\" --copy-command wl-copy --early-exit");
  }

  function run(script) {
    mainProc.command = ["bash", "-lc", script];
    mainProc.running = true;
  }

  Process {
    id: mainProc
    command: ["bash", "-lc", "true"]
    running: false
  }

  Process {
    id: windowProc
    command: ["bash", "-lc", "hyprctl activewindow -j"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const win = JSON.parse(text);
          if (win && win.at && win.size) root.grab(win.at[0] + "," + win.at[1] + " " + win.size[0] + "x" + win.size[1], "");
        } catch (e) {
        }
      }
    }
  }

  Process {
    id: monitorProc
    command: ["bash", "-lc", "hyprctl monitors -j"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const monitors = JSON.parse(text);
          const focused = monitors.find((m) => m.focused) || monitors[0];
          if (focused) root.grab("", focused.name);
        } catch (e) {
        }
      }
    }
  }
}
