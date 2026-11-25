#!/usr/bin/env bash
# Shared helpers — sourced by every sysinfo-*.sh

BOLD=$'\033[1m'; DIM=$'\033[2m'; CYAN=$'\033[0;36m'
GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; NC=$'\033[0m'

clamp(){ local v="${1:-0}"; [[ "$v" =~ ^-?[0-9]+$ ]] || v=0
         [ "$v" -lt 0 ] && v=0; [ "$v" -gt 100 ] && v=100; echo "$v"; }

pct_color(){ local p; p=$(clamp "${1:-0}")
  if [ "$p" -lt 50 ]; then echo "$GREEN"
  elif [ "$p" -lt 80 ]; then echo "$YELLOW"
  else echo "$RED"; fi; }

pct_str(){ local p; p=$(clamp "${1:-0}")
  printf '%s%3d%%%s' "$(pct_color "$p")" "$p" "$NC"; }

bar(){ local p; p=$(clamp "${1:-0}"); local w=${2:-22} f e i
  f=$((p*w/100)); e=$((w-f))
  printf '%s' "$(pct_color "$p")"
  for((i=0;i<f;i++));do printf '█';done
  printf '%s' "$DIM"
  for((i=0;i<e;i++));do printf '░';done
  printf '%s' "$NC"; }

hdr(){ printf '%s%s\n' "$CYAN" "$BOLD"
  printf '╔══════════════════════════════════════════════╗\n'
  printf '║        TERMINAL SYSTEM INFO TOOL             ║\n'
  printf '╚══════════════════════════════════════════════╝\n'
  printf '%s\n\n' "$NC"; }

row(){ printf '  %s%-11s%s %s\n' "$BOLD" "$1" "$NC" "$2"; }

row_bar(){
  local label="$1" value="$2" pct="$3" extra="${4:-}"
  printf '  %s%-11s%s ' "$BOLD" "$label" "$NC"
  if [ -n "$extra" ]; then printf '%s  ' "$extra"; fi
  pct_str "$pct"; printf '  '; bar "$pct" 22; echo
}

footer(){ printf '\n%s' "$DIM"; printf '─%.0s' {1..48}; printf '%s\n' "$NC"; }

need_pkg(){
  printf '  %s%-11s%s %s%s%s\n' "$BOLD" "$1" "$NC" "$DIM" "$2" "$NC"
}
