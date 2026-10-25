#!/usr/bin/env bash
tmp=$(mktemp -d) || exit 0
trap 'rm -rf "$tmp"' EXIT
t1=$tmp/c
t4=$tmp/g
t5=$tmp/w

awk '
  function rindex(s, t,  i, k) {
    k = 0
    while ((i = index(substr(s, k + 1), t)) > 0) {
      k += i
    }
    return k
  }
  function sup(c) {
    c = tolower(c)
    return c == "systemd" || c == "init" || c == "sd-pam" || c == "login" || c == "zellij" || c == "tmux" || c == "sudo" || c == "doas" || c == "sshd" || c == "fish" || c == "bash" || c == "zsh" || c == "sh" || c == "dash" || c ~ /^start-hyprland/ || c ~ /^\.?hyprland/ || c ~ /^\.?quickshell/
  }
  function mach(c) {
    c = tolower(c)
    return c == "reaper" || c == "steamlaunch" || c == "srt-bwrap" || c == "pv-adverb" || c == "sniper" || c == "soldier" || c == "_v2-entry-point" || c ~ /^pressure-vessel/ || c ~ /^steam-runtime/
  }
  function launchtop(x,  up, d, hit) {
    d = 0
    hit = 0
    while (d++ < 64) {
      if (tolower(nm[x]) == "reaper" || tolower(nm[x]) == "steamlaunch") {
        hit = 1
      }
      up = pp[x]
      if (!(up > 1 && (up in nm) && mach(nm[up]))) {
        break
      }
      x = up
    }
    return hit ? x : 0
  }
  function loadlibs(  path, line, f) {
    nlib = 0
    path = ENVIRON["HOME"] "/.local/share/Steam/steamapps/libraryfolders.vdf"
    while ((getline line < path) > 0) {
      if (line ~ /"path"/) {
        split(line, f, "\"")
        if (f[4] != "") {
          LB[++nlib] = f[4] "/steamapps"
        }
      }
    }
    close(path)
    if (nlib == 0) {
      LB[++nlib] = ENVIRON["HOME"] "/.local/share/Steam/steamapps"
    }
    return nlib
  }
  function acfname(a,  i, path, line, f) {
    for (i = 1; i <= nlib; i++) {
      path = LB[i] "/appmanifest_" a ".acf"
      while ((getline line < path) > 0) {
        if (line ~ /^[ \t]*"name"[ \t]*"/) {
          close(path)
          split(line, f, "\"")
          if (f[4] != "") {
            return f[4]
          }
        }
      }
      close(path)
    }
    return ""
  }
  function iconpath(a,  base, cmd, f, p) {
    base = ENVIRON["HOME"] "/.local/share/Steam/appcache/librarycache/" a
    cmd = "ls -1 " base " 2>/dev/null"
    while ((cmd | getline f) > 0) {
      if (f ~ /^[0-9a-f]{40}\.jpg$/) {
        close(cmd)
        return "file://" base "/" f
      }
    }
    close(cmd)
    p = base "_icon.jpg"
    if ((getline f < p) >= 0) {
      close(p)
      return "file://" p
    }
    close(p)
    return ""
  }
  function appidof(p,  line, nul, n, t, i) {
    if ((getline line < ("/proc/" p "/cmdline")) <= 0) {
      close("/proc/" p "/cmdline")
      return 0
    }
    close("/proc/" p "/cmdline")
    nul = sprintf("%c", 0)
    gsub(nul, " ", line)
    n = split(line, t, " ")
    for (i = 1; i <= n; i++) {
      if (t[i] ~ /^AppId=[0-9]+$/) {
        return substr(t[i], 7) + 0
      }
    }
    return 0
  }
  function leader(p,  up, d, t) {
    d = 0
    up = pp[p]
    while (up > 1 && (up in nm) && d++ < 64) {
      if (sup(nm[up])) {
        break
      }
      if (mach(nm[up]) && !sup(nm[p]) && !mach(nm[p])) {
        t = launchtop(up)
        if (t > 0) {
          return t
        }
      }
      p = up
      up = pp[p]
    }
    return p
  }
  function full(p,  orig, c, line, nul, i, n, seg, base) {
    if (length(orig) != 15) {
      return orig
    }
    c = orig
    if (substr(c, 1, 1) == ".") {
      c = substr(c, 2)
    }
    if ((getline line < ("/proc/" p "/cmdline")) <= 0) {
      close("/proc/" p "/cmdline")
      return orig
    }
    close("/proc/" p "/cmdline")
    nul = sprintf("%c", 0)
    i = index(line, nul)
    if (i > 0) {
      line = substr(line, 1, i - 1)
    }
    n = split(line, seg, /[\/\\]/)
    base = seg[n]
    if (base != "" && index(base, c) == 1) {
      return base
    }
    return orig
  }
  {
    path = $0
    pid = path
    sub(/^\/proc\//, "", pid)
    sub(/\/stat$/, "", pid)
    if ((getline line < path) <= 0) {
      close(path)
      next
    }
    close(path)
    b = index(line, "(")
    e = rindex(line, ")")
    comm = substr(line, b + 1, e - b - 1)
    split(substr(line, e + 2), f, " ")
    if (pid == 1 && comm != "systemd") {
      nm["1"] = comm
      pp["1"] = 0
      next
    }
    if (f[2] == 2 || f[2] + 0 == 0 || comm ~ /^\[/) {
      next
    }
    nm[pid] = full(pid, comm)
    pp[pid] = f[2] + 0
    rss = 0
    if ((getline line < ("/proc/" pid "/statm")) > 0) {
      split(line, s, " ")
      rss = s[2] * 4096
    }
    close("/proc/" pid "/statm")
    iob = -1
    if ((getline line < ("/proc/" pid "/io")) > 0) {
      iob = 0
      do {
        if (sub(/^read_bytes:[ \t]*/, "", line) || sub(/^write_bytes:[ \t]*/, "", line)) {
          iob += line + 0
        }
      } while ((getline line < ("/proc/" pid "/io")) > 0)
    }
    close("/proc/" pid "/io")
    tk[pid] = f[12] + f[13]
    rs[pid] = rss
    io[pid] = iob
  }
  END {
    for (p in nm) {
      ld[p] = leader(p + 0)
    }
    for (p in nm) {
      l = ld[p]
      if (!mach(nm[l])) {
        continue
      }
      pri = mach(nm[p]) ? (p + 0 == l ? 0 : -1) : 1
      if (!(l in brs) || pri > bpri[l] || (pri == bpri[l] && (rs[p] > brs[l] || (rs[p] == brs[l] && tk[p] > btk[l])))) {
        brs[l] = rs[p]
        btk[l] = tk[p]
        bpri[l] = pri
        rep[l] = p
      }
    }
    for (p in nm) {
      l = ld[p]
      if (l in rep) {
        l = rep[l] + 0
      }
      print "C\t" p "\t" nm[p] "\t" tk[p] "\t" rs[p] "\t" io[p] "\t" l
    }
    nlib = loadlibs()
    for (l in rep) {
      a = appidof(l + 0)
      if (a <= 0) {
        continue
      }
      gname = acfname(a)
      if (gname == "") {
        continue
      }
      print "W\t" rep[l] "\t" gname "\t" iconpath(a)
    }
  }
' <<< "$(ls -d /proc/[0-9]*/stat 2>/dev/null)" > "$t1"

grep -H -e '^drm-client-id' -e '^drm-engine-' -e '^drm-memory-vram' /proc/[0-9]*/fdinfo/* 2>/dev/null | awk '
  {
    path = $0
    sub(/:.*/, "", path)
    rest = substr($0, length(path) + 2)
    key = rest
    sub(/:.*/, "", key)
    val = rest
    sub(/^[^:]*:[ \t]*/, "", val)
    gsub(/[^0-9]/, "", val)
    v = val + 0
    split(path, a, "/")
    pid = a[3]
    fd = a[5]
    k = pid SUBSEP fd
    if (key == "drm-client-id") {
      cl[k] = v
    } else if (key ~ /^drm-engine-/) {
      en[k] += v
    } else if (key == "drm-memory-vram") {
      me[k] += v
    }
  }
  END {
    for (k in cl) {
      split(k, b, SUBSEP)
      c = b[1] SUBSEP cl[k]
      if (en[k] > EN[c]) {
        EN[c] = en[k]
      }
      if (me[k] > ME[c]) {
        ME[c] = me[k]
      }
      seen[c] = 1
    }
    for (c in seen) {
      split(c, b, SUBSEP)
      print "G\t" b[1] "\t" (EN[c] + 0) "\t" (ME[c] + 0)
    }
  }
' > "$t4"

ss -tinp state established 2>/dev/null | awk '
  function pidget(s) {
    if (match(s, /pid=[0-9]+/)) {
      return substr(s, RSTART + 4, RLENGTH - 4) + 0
    }
    return 0
  }
  /^[^ \t]/ {
    cur = pidget($0)
    next
  }
  /^[ \t]/ {
    p = pidget($0)
    if (p > 0) {
      cur = p
    }
    if (cur > 0 && match($0, /bytes_acked:[0-9]+/)) {
      a = substr($0, RSTART + 12, RLENGTH - 12) + 0
      rest = substr($0, RSTART + RLENGTH)
      if (match(rest, /bytes_received:[0-9]+/)) {
        b = substr(rest, RSTART + 15, RLENGTH - 15) + 0
        nt[cur] += a + b
      }
    }
  }
  END {
    for (p in nt) {
      print "T\t" p "\t" nt[p]
    }
  }
' > "$t5"

echo "H	$(nproc 2>/dev/null || echo 1)"

awk -F'\t' '
  $1 == "C" { nm[$2] = $3; tk[$2] = $4 + 0; rs[$2] = $5 + 0; io[$2] = $6 + 0; ld[$2] = $7 + 0; next }
  $1 == "W" { gn[$2] = $3; gi[$2] = $4; next }
  $1 == "N" { dg[$2] = $3 + 0; next }
  $1 == "V" { dv[$2] = $3 + 0; next }
  $1 == "G" { ge[$2] += $3 + 0; gv[$2] += $4 + 0; next }
  $1 == "T" { nt[$2] += $3 + 0; next }
  END {
    for (pid in nm) {
      l = (pid in ld) ? ld[pid] : pid + 0
      print "P\t" pid "\t" nm[pid] "\t" tk[pid] "\t" rs[pid] "\t" io[pid] "\t" ((pid in dg) ? dg[pid] : -1) "\t" ((pid in dv) ? dv[pid] : -1) "\t" ((pid in ge) ? ge[pid] : -1) "\t" ((pid in gv) ? gv[pid] : -1) "\t" ((pid in nt) ? nt[pid] : -1) "\t" ((l in nm) ? l : pid + 0)
    }
    for (pid in gn) {
      print "M\t" pid "\t" gn[pid] "\t" gi[pid]
    }
  }
' "$t1" "$t2" "$t3" "$t4" "$t5"
