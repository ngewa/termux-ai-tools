#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Knowledge Memory & AI Brain Launcher for Termux AI Tools
# ==============================================================================

REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_PATH")" && pwd)"
exec bash "$SCRIPT_DIR/bin/memory-manager.sh" "$@"
