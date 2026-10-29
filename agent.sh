#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# AI Persona & Subagent Manager Launcher for Termux AI Tools (agent.sh / aiagent)
# ==============================================================================

REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_PATH")" && pwd)"
exec bash "$SCRIPT_DIR/bin/agent-manager.sh" "$@"
