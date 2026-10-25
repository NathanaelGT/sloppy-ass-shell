#!/usr/bin/env bash
nvidia-smi pmon -c 1 -s um 2>/dev/null | awk '
  NR == 1 {
    for (i = 2; i <= NF; i++) {
      c = $i
      if (c == "sm") {
        smc = i - 1
      }
      if (c == "fb") {
        fbc = i - 1
      }
    }
    next
  }
  $1 !~ /^#/ && $2 ~ /^[0-9]+$/ && smc > 0 {
    u = ($smc ~ /^[0-9.]+$/) ? $smc + 0 : -1
    m = (fbc > 0 && $fbc ~ /^[0-9.]+$/) ? $fbc * 1024 : -1
    print "N\t" $2 "\t" u "\t" m
  }
'
nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.used,memory.total,clocks.sm,name --format=csv,noheader 2>/dev/null | head -n1 | awk -F',' '
  {
    for (i = 1; i <= 5; i++) {
      gsub(/[^0-9.]/, "", $i)
    }
    clock = $6
    gsub(/^ +| +$/, "", clock)
    name = $7
    for (i = 8; i <= NF; i++) {
      name = name "," $i
    }
    gsub(/^ +| +$/, "", name)
    print "D\t" $1 + 0 "\t" $2 + 0 "\t" $3 + 0 "\t" $4 + 0 "\t" $5 + 0 "\t" clock "\t" name
  }
'
