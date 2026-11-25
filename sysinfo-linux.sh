#!/usr/bin/env bash
set -u
SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SELF/lib/common.sh"

get_os(){
  if [ -r /etc/os-release ]; then . /etc/os-release; echo "${PRETTY_NAME:-Linux}"
  else uname -s; fi
}
get_uptime(){
  local s d h m out=""
  s=$(awk '{print int($1)}' /proc/uptime 2>/dev/null) || { echo "N/A"; return; }
  d=$((s/86400)); h=$(((s%86400)/3600)); m=$(((s%3600)/60))
  [ "$d" -gt 0 ] && { out="$d day"; [ "$d" -gt 1 ] && out="${out}s"; out="$out, "; }
  printf '%s%dh %dm' "$out" "$h" "$m"
}
get_cpu(){
  local _ u1 n1 s1 i1 w1 q1 sq1 st1 u2 n2 s2 i2 w2 q2 sq2 st2
  read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat || { echo "na:"; return; }
  local t1=$((u1+n1+s1+i1+w1+q1+sq1+st1)) id1=$((i1+w1))
  sleep 0.4
  read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat || { echo "na:"; return; }
  local t2=$((u2+n2+s2+i2+w2+q2+sq2+st2)) id2=$((i2+w2))
  local dt=$((t2-t1)) did=$((id2-id1))
  [ "$dt" -le 0 ] && { echo "na:"; return; }
  echo "usage:$(( 100*(dt-did)/dt ))"
}
get_ram(){
  local tk ak
  tk=$(awk '/^MemTotal:/{print $2}'     /proc/meminfo 2>/dev/null)
  ak=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)
  [ -z "${ak:-}" ] && ak=$(awk '/^MemFree:/{print $2}' /proc/meminfo 2>/dev/null)
  [ -z "${tk:-}" ] || [ -z "${ak:-}" ] || [ "$tk" -le 0 ] && { echo "0 0 0"; return; }
  local uk=$((tk-ak))
  echo "$((uk/1024)) $((tk/1024)) $((100*uk/tk))"
}
get_battery(){
  local b
  for b in /sys/class/power_supply/BAT*; do
    [ -d "$b" ] && [ -r "$b/capacity" ] || continue
    echo "$(cat "$b/capacity")% ($(cat "$b/status" 2>/dev/null || echo Unknown))"; return
  done
  echo "N/A (no battery)"
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
row "OS"        "$(get_os)"
row "Kernel"    "$(uname -r)"
row "Hostname"  "$(uname -n)"
row "Uptime"    "$(get_uptime)"
echo

raw=$(get_cpu); kind="${raw%%:*}"; val="${raw#*:}"
if [ "$kind" = usage ]; then row_bar "CPU" "" "$val"
else row "CPU" "N/A"; fi
echo

read -r ru rt rp < <(get_ram)
[ "${rt:-0}" -gt 0 ] && row_bar "RAM" "" "$rp" "$ru / $rt MB" || row "RAM" "N/A"
echo

storage / "Root"
[ -d /home ] && [ "$(df --output=target /home 2>/dev/null | tail -1)" != "/" ] && storage /home "Home"
echo

row "Battery" "$(get_battery)"
footer
