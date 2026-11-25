#!/usr/bin/env bash
# =====================================================
#  Terminal System Info Tool — Termux / Android
# =====================================================
set -u

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SELF/lib/common.sh"

HAS_API=0
command -v termux-battery-status >/dev/null 2>&1 && HAS_API=1

# getprop is not in PATH on Termux by default
_GP=""
if command -v getprop >/dev/null 2>&1; then
  _GP="getprop"
elif [ -x /system/bin/getprop ]; then
  _GP="/system/bin/getprop"
fi

# ---------- collectors ----------
get_os(){
  local v="" m="" s="Android"
  if [ -n "$_GP" ]; then
    v=$($_GP ro.build.version.release 2>/dev/null)
    m=$($_GP ro.product.model       2>/dev/null)
  fi
  [ -n "$v" ] && s="$s $v"
  [ -n "$m" ] && s="$s ($m)"
  echo "$s [Termux]"
}

get_hostname(){
  local h=""
  [ -n "$_GP" ] && h=$($_GP net.hostname 2>/dev/null)
  if [ -n "$h" ]; then echo "$h"; else uname -n; fi
}

get_uptime(){
  local s
  s=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
  if [ -z "$s" ] || ! [[ "$s" =~ ^[0-9]+$ ]]; then
    if command -v termux-info >/dev/null 2>&1; then
      local line d h m out=""
      line=$(termux-info 2>/dev/null | grep -i 'uptime' | head -1)
      if [ -n "$line" ]; then
        d=$(echo "$line" | grep -oiE '[0-9]+ day'    | grep -o '[0-9]*' || echo 0)
        h=$(echo "$line" | grep -oiE '[0-9]+ hour'   | grep -o '[0-9]*' || echo 0)
        m=$(echo "$line" | grep -oiE '[0-9]+ minute' | grep -o '[0-9]*' || echo 0)
        [ "${d:-0}" -gt 0 ] && { out="$d day"; [ "$d" -gt 1 ] && out="${out}s"; out="$out, "; }
        printf '%s%dh %dm' "$out" "${h:-0}" "${m:-0}"; return
      fi
    fi
    echo "N/A (blocked by Android)"; return
  fi
  local d=$((s/86400)) h=$(((s%86400)/3600)) m=$(((s%3600)/60)) out=""
  [ "$d" -gt 0 ] && { out="$d day"; [ "$d" -gt 1 ] && out="${out}s"; out="$out, "; }
  printf '%s%dh %dm' "$out" "$h" "$m"
}

# echoes: "usage:PCT" | "approx:PCT:DETAIL" | "na:"
get_cpu(){
  # 1. /proc/stat (accurate; blocked on Android 12+)
  if head -c 4 /proc/stat >/dev/null 2>&1; then
    local _ u1 n1 s1 i1 w1 q1 sq1 st1 u2 n2 s2 i2 w2 q2 sq2 st2
    if read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat 2>/dev/null; then
      local t1=$((u1+n1+s1+i1+w1+q1+sq1+st1)) id1=$((i1+w1))
      sleep 0.4
      if read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat 2>/dev/null; then
        local t2=$((u2+n2+s2+i2+w2+q2+sq2+st2)) id2=$((i2+w2))
        local dt=$((t2-t1)) did=$((id2-id1))
        [ "$dt" -gt 0 ] && { echo "usage:$(( 100*(dt-did)/dt ))"; return; }
      fi
    fi
  fi

  local cores
  cores=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
  [ "${cores:-0}" -lt 1 ] && cores=1

  # 2. /proc/loadavg (also blocked on Android 14)
  if [ -r /proc/loadavg ]; then
    local la
    la=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
    if [ -n "$la" ]; then
      local approx
      approx=$(awk -v la="$la" -v c="$cores" 'BEGIN{printf "%d",(la/c)*100}')
      echo "approx:$approx:load $la / $cores cores"; return
    fi
  fi

  # 3. ps fallback — works on Android 14+ (toybox or procps)
  if command -v ps >/dev/null 2>&1; then
    local sum
    sum=$(ps -A -o %cpu 2>/dev/null | awk 'NR>1{s+=$1} END{printf "%.0f", s+0}')
    if [ -z "${sum:-}" ] || [ "${sum:-0}" -eq 0 ]; then
      sum=$(ps -A -o pcpu 2>/dev/null | awk 'NR>1{s+=$1} END{printf "%.0f", s+0}')
    fi
    if [ -n "${sum:-}" ] && [ "${sum:-0}" -gt 0 ]; then
      local approx
      approx=$(awk -v s="$sum" -v c="$cores" 'BEGIN{p=s/c; if(p>100)p=100; printf "%d", p}')
      echo "approx:$approx:ps sum ${sum}% / $cores cores"; return
    fi
  fi

  echo "na:"
}

get_ram(){
  local tk ak
  tk=$(awk '/^MemTotal:/{print $2}'     /proc/meminfo 2>/dev/null)
  ak=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)
  [ -z "${ak:-}" ] && ak=$(awk '/^MemFree:/{print $2}' /proc/meminfo 2>/dev/null)
  if [ -z "${tk:-}" ] || [ -z "${ak:-}" ] || [ "$tk" -le 0 ]; then
    echo "0 0 0"; return
  fi
  local uk=$((tk-ak))
  echo "$((uk/1024)) $((tk/1024)) $((100*uk/tk))"
}

# Cached battery — instant after first call, TTL 30s.
get_battery(){
  [ "${SYSINFO_NO_BATTERY:-0}" = 1 ] && { echo "disabled (SYSINFO_NO_BATTERY=1)"; return; }

  local cache="$HOME/.cache/sysinfo-battery"
  mkdir -p "$HOME/.cache" 2>/dev/null

  if [ -f "$cache" ]; then
    local ts now
    ts=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null)
    now=$(date +%s)
    if [ -n "$ts" ] && [ $((now - ts)) -lt 30 ]; then
      cat "$cache"; return
    fi
  fi

  if [ "$HAS_API" = 1 ]; then
    local o p s out
    if command -v timeout >/dev/null 2>&1; then
      o=$(timeout 3 termux-battery-status 2>/dev/null)
    else
      o=$(termux-battery-status 2>/dev/null)
    fi
    p=$(echo "$o" | grep -o '"percentage":[0-9]*' | head -1 | cut -d: -f2)
    s=$(echo "$o" | grep -o '"status":"[^"]*"'     | head -1 | cut -d'"' -f4)
    if [ -n "$p" ]; then
      out="${p}% (${s:-Unknown})"
      echo "$out" > "$cache"
      echo "$out"; return
    fi
  fi
  echo "N/A (pkg install termux-api)"
}

storage(){
  local path="$1" label="$2" size used pct mp info
  info=$(df -h "$path" 2>/dev/null | awk 'NR==2{print $2,$3,$5,$6}')
  [ -z "$info" ] && return
  read -r size used pct mp <<< "$info"
  pct=${pct%\%}
  printf '  %s%-11s%s %s / %s\n' "$BOLD" "$label" "$NC" "$used" "$size"
  printf '  %-11s ' ""
  pct_str "$pct"; printf '  '; bar "$pct" 22; echo
}

# ---------- output ----------
hdr

row "OS"        "$(get_os)"
row "Kernel"    "$(uname -r)"
row "Hostname"  "$(get_hostname)"
row "Uptime"    "$(get_uptime)"
echo

raw=$(get_cpu)
kind="${raw%%:*}"
case "$kind" in
  usage)
    val="${raw#*:}"
    row_bar "CPU" "" "$val"
    ;;
  approx)
    IFS=: read -r _ approx detail <<< "$raw"
    printf '  %s%-11s%s ' "$BOLD" "CPU" "$NC"
    pct_str "$approx"
    printf '  (%s)\n' "$detail"
    printf '  %-11s ' ""; bar "$approx" 22; echo
    ;;
  *)
    row "CPU" "N/A (blocked by Android)"
    ;;
esac
echo

read -r ru rt rp < <(get_ram)
if [ "${rt:-0}" -gt 0 ]; then
  row_bar "RAM" "" "$rp" "$ru / $rt MB"
else
  row "RAM" "N/A"
fi
echo

storage "$HOME" "Termux"
[ -d /storage/emulated/0 ] && storage /storage/emulated/0 "Internal"
echo

row "Battery" "$(get_battery)"
[ "$HAS_API" = 0 ] && need_pkg "" "Tip: pkg install termux-api  (also install the Termux:API app)"
footer
