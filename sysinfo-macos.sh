#!/usr/bin/env bash
set -u
SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$SELF/lib/common.sh"

get_uptime(){
  local boot s d h m out=""
  boot=$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | tr -d ',')
  [ -z "$boot" ] && { echo "N/A"; return; }
  s=$(( $(date +%s) - boot ))
  d=$((s/86400)); h=$(((s%86400)/3600)); m=$(((s%3600)/60))
  [ "$d" -gt 0 ] && { out="$d day"; [ "$d" -gt 1 ] && out="${out}s"; out="$out, "; }
  printf '%s%dh %dm' "$out" "$h" "$m"
}
get_cpu(){
  local u
  u=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/{gsub("%","");print $3+$5}')
  [ -z "$u" ] && { echo "na:"; return; }
  echo "usage:${u%.*}"
}
get_ram(){
  local ps total vm active wired comp used
  ps=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
  total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  vm=$(vm_stat 2>/dev/null || true)
  active=$(echo "$vm" | awk '/Pages active/{gsub("\\.","");print $3}')
  wired=$(echo "$vm"  | awk '/Pages wired/{gsub("\\.","");print $4}')
  comp=$(echo "$vm"   | awk '/Pages occupied by compressor/{gsub("\\.","");print $5}')
  : "${active:=0}" "${wired:=0}" "${comp:=0}"
  used=$(( (active + wired + comp) * ps ))
  [ "$total" -le 0 ] && { echo "0 0 0"; return; }
  echo "$((used/1048576)) $((total/1048576)) $((used*100/total))"
}
get_battery(){
  local line pct st
  line=$(pmset -g batt 2>/dev/null | grep -E 'InternalBattery|Battery' | head -1)
  [ -z "$line" ] && { echo "N/A (no battery)"; return; }
  pct=$(echo "$line" | grep -o '[0-9]*%' | head -1)
  st=$(echo "$line" | awk -F';' '{gsub(/^ +/,"",$2); print $2}')
  echo "${pct:-?} (${st:-Unknown})"
}
storage(){
  local path="$1" label="$2" size used pct mp
  local info; info=$(df -h "$path" 2>/dev/null | awk 'NR==2{print $2,$3,$5,$6}')
  [ -z "$info" ] && return
  read -r size used pct mp <<< "$info"; pct=${pct%\%}
  printf '  %s%-11s%s %s / %s (%s)\n' "$BOLD" "$label" "$NC" "$used" "$size" "$mp"
  printf '  %-11s ' ""; pct_str "$pct"; printf '  '; bar "$pct" 22; echo
}

hdr
row "OS"        "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
row "Kernel"    "$(uname -r)"
row "Hostname"  "$(uname -n)"
row "Uptime"    "$(get_uptime)"
echo

raw=$(get_cpu); kind="${raw%%:*}"; val="${raw#*:}"
[ "$kind" = usage ] && row_bar "CPU" "" "$val" || row "CPU" "N/A"
echo

read -r ru rt rp < <(get_ram)
[ "${rt:-0}" -gt 0 ] && row_bar "RAM" "" "$rp" "$ru / $rt MB" || row "RAM" "N/A"
echo

storage / "Root"
storage /System/Volumes/Data "Data"
echo
row "Battery" "$(get_battery)"
footer
