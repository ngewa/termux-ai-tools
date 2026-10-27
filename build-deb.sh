#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Helper script to build .deb packages for OpenCode and Antigravity CLI
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/dist"
mkdir -p "$OUTPUT_DIR"

GREEN="\033[32m"
CYAN="\033[36m"
RESET="\033[0m"

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }

chmod 755 "$SCRIPT_DIR"/packages/*/DEBIAN
chmod 755 "$SCRIPT_DIR"/packages/*/DEBIAN/*

log_info "Building opencode .deb package..."
dpkg-deb -b "$SCRIPT_DIR/packages/opencode" "$OUTPUT_DIR/opencode_1.19.4_all.deb"
log_ok "Built: $OUTPUT_DIR/opencode_1.19.4_all.deb"

log_info "Building opencode-v2 .deb package..."
dpkg-deb -b "$SCRIPT_DIR/packages/opencode-v2" "$OUTPUT_DIR/opencode-v2_2.2.0_all.deb"
log_ok "Built: $OUTPUT_DIR/opencode-v2_2.2.0_all.deb"

log_info "Building antigravity-cli .deb package..."
dpkg-deb -b "$SCRIPT_DIR/packages/antigravity-cli" "$OUTPUT_DIR/antigravity-cli_1.3.5_all.deb"
log_ok "Built: $OUTPUT_DIR/antigravity-cli_1.3.5_all.deb"

log_ok "Semua paket .deb berhasil dibuat di direktori: $OUTPUT_DIR"
