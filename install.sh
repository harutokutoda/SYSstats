#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

detect_os(){
  if [ -n "${TERMUX_VERSION:-}" ] || [[ "${PREFIX:-}" == *com.termux* ]]; then
    echo "termux"; return
  fi
  case "$(uname -s 2>/dev/null)" in
    Darwin)                echo "macos"   ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null
      then echo "wsl"; else echo "linux"; fi ;;
    *) echo "unknown" ;;
  esac
}

OS=$(detect_os)
case "$OS" in
  termux)  SRC="$SCRIPT_DIR/sysinfo-termux.sh"  ;;
  macos)   SRC="$SCRIPT_DIR/sysinfo-macos.sh"   ;;
  wsl)     SRC="$SCRIPT_DIR/sysinfo-wsl.sh"     ;;
  linux)   SRC="$SCRIPT_DIR/sysinfo-linux.sh"   ;;
  *)
    echo "❌ Unsupported OS: $(uname -s 2>/dev/null || echo unknown)"
    echo "   On Windows, run:  .\\install.ps1"
    exit 1 ;;
esac

if [ ! -f "$SRC" ]; then
  echo "❌ Missing $SRC — did you clone the whole repo?"
  exit 1
fi

# Strip CRLF & ensure +x on all bash files
for f in "$SRC" "$SCRIPT_DIR/lib/common.sh"; do
  [ -f "$f" ] && sed -i 's/\r$//' "$f" 2>/dev/null || true
  chmod +x "$f" 2>/dev/null || true
done

echo "Detected OS: $OS"
echo "Using script: $(basename "$SRC")"
read -rp "Shortcut name (default: sysinfo): " CODE
CODE="${CODE:-sysinfo}"
[[ "$CODE" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]] || { echo "❌ invalid name"; exit 1; }

# --- Termux: install into $PREFIX/bin (always on PATH) ---
if [ "$OS" = termux ] || [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ]; then
  DEST="$PREFIX/bin/$CODE"
  cat > "$DEST" <<EOF
#!${PREFIX}/bin/bash
export SYSINFO_LIB="${SCRIPT_DIR}/lib"
exec "${SRC}" "\$@"
EOF
  chmod +x "$DEST"
  echo "✅ Installed: $DEST"
  echo "   Run: $CODE"
  echo
  echo "   For battery:  pkg install termux-api"
  exit 0
fi

# --- Linux / macOS: install into ~/.local/bin if on PATH ---
LOCALBIN="$HOME/.local/bin"
case ":$PATH:" in
  *":$LOCALBIN:"*)
    mkdir -p "$LOCALBIN"
    ln -sf "$SRC" "$LOCALBIN/$CODE"
    echo "✅ Symlinked: $LOCALBIN/$CODE → $SRC"
    echo "   Run: $CODE"
    exit 0 ;;
esac

# --- Fallback alias ---
RC="$HOME/.bashrc"; [ -n "${ZSH_VERSION:-}" ] && RC="$HOME/.zshrc"
touch "$RC"
TMP=$(mktemp); grep -v "^alias ${CODE}=" "$RC" > "$TMP" 2>/dev/null || true
mv "$TMP" "$RC"
printf '\n# Terminal System Info Tool\nalias %s=%q\n' "$CODE" "$SRC" >> "$RC"
echo "✅ Added alias '$CODE' → $RC"
echo "   Reload: source $RC"
