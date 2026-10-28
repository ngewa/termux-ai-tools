#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Plugin & MCP Tool Installer Launcher for Termux AI Tools
# ==============================================================================

REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_PATH")" && pwd)"
exec bash "$SCRIPT_DIR/bin/plugin-installer.sh" "$@"
