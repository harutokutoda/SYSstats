cat > ~/systemstats/README.md <<'EOF'
# 🖥️ Terminal System Info Tool

A cross-platform system stats panel — OS, kernel, hostname, uptime,
CPU %, RAM, storage and battery — in one command.

## Install

| Platform | Command |
|---|---|
| Linux    | `./install.sh` |
| macOS    | `./install.sh` |
| Termux   | `./install.sh` |
| WSL      | `./install.sh` |
| Windows  | `powershell -ExecutionPolicy Bypass -File install.ps1` |

The installer auto-detects your OS and writes a `sysinfo` command to your PATH.

## Use

```bash
sysinfo
