#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# AI Tools Updater for Termux (OpenCode & Antigravity CLI)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err() { echo -e "${RED}[ERROR]${RESET} $1"; }

echo -e "\n${BOLD}${CYAN}=== Memeriksa Update AI Tools di Termux ===${RESET}\n"

# 1. Check OpenCode
OPENCODE_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/opencode" ]; then
    OPENCODE_INSTALLED=$("$PREFIX/bin/opencode" --version 2>/dev/null || echo "Unknown")
fi

log_info "Memeriksa versi upstream OpenCode..."
OPENCODE_LATEST_TAG=$(curl -sL https://api.github.com/repos/anomalyco/opencode/releases/latest | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
OPENCODE_LATEST="${OPENCODE_LATEST_TAG#v}"
if [ -z "$OPENCODE_LATEST" ]; then
    OPENCODE_LATEST="1.19.4"
fi

# 2. Check AGY (Antigravity CLI)
AGY_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/agy" ]; then
    AGY_INSTALLED=$("$PREFIX/bin/agy" --version 2>/dev/null || echo "Unknown")
fi

log_info "Memeriksa versi upstream Antigravity CLI..."
AGY_LATEST=$(curl -sL https://api.github.com/repos/google-antigravity/antigravity-cli/releases/latest | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "1.4.8")
AGY_LATEST="${AGY_LATEST#v}"
if [ -z "$AGY_LATEST" ]; then
    AGY_LATEST="1.4.8"
fi

echo -e "\n${BOLD}Ringkasan Status:${RESET}"
printf "%-18s | %-16s | %-16s | %-10s\n" "Software" "Terpasang" "Upstream" "Status"
echo "----------------------------------------------------------------------"

# OpenCode status
if [ "$OPENCODE_INSTALLED" = "$OPENCODE_LATEST" ]; then
    OPENCODE_STATUS="${GREEN}Up-to-date${RESET}"
elif [ "$OPENCODE_INSTALLED" = "Tidak terpasang" ]; then
    OPENCODE_STATUS="${YELLOW}Belum ada${RESET}"
else
    OPENCODE_STATUS="${RED}Ada update!${RESET}"
fi
printf "%-18s | %-16s | %-16s | %-10b\n" "OpenCode" "$OPENCODE_INSTALLED" "$OPENCODE_LATEST" "$OPENCODE_STATUS"

# AGY status
# Catatan: v1.3.5 adalah versi stabil yang ter-patch untuk Termux.
if [ "$AGY_INSTALLED" = "1.3.5" ]; then
    AGY_STATUS="${GREEN}Stabil (1.3.5)${RESET}"
elif [ "$AGY_INSTALLED" = "$AGY_LATEST" ]; then
    AGY_STATUS="${GREEN}Up-to-date${RESET}"
elif [ "$AGY_INSTALLED" = "Tidak terpasang" ]; then
    AGY_STATUS="${YELLOW}Belum ada${RESET}"
else
    AGY_STATUS="${YELLOW}Stabil (1.3.5)${RESET}"
fi
printf "%-18s | %-16s | %-16s | %-10b\n" "Antigravity CLI" "$AGY_INSTALLED" "$AGY_LATEST" "$AGY_STATUS"
echo "----------------------------------------------------------------------"
echo -e "${YELLOW}Catatan AGY:${RESET} Versi 1.3.5 adalah build yang paling stabil & kompatibel dengan patch memori Termux."
echo ""

TARGET="$1"

# Handle arguments
if [ "$TARGET" = "opencode" ]; then
    log_info "Memulai update OpenCode ke versi $OPENCODE_LATEST..."
    bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST" --force
    exit 0
elif [ "$TARGET" = "agy" ]; then
    log_info "Memulai update / reinstal Antigravity CLI (1.3.5 stabil)..."
    bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5" --force
    exit 0
elif [ "$TARGET" = "all" ]; then
    log_info "Mengupdate OpenCode & AGY..."
    bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST"
    bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5"
    exit 0
fi

# Interactive prompt if no arguments
echo -e "${BOLD}Pilihan tindakan:${RESET}"
echo "1) Update OpenCode ke versi terbaru ($OPENCODE_LATEST)"
echo "2) Pasang / Reinstall Antigravity CLI (v1.3.5 stabil)"
echo "3) Update / Sinkronisasi Keduanya"
echo "4) Keluar"
read -r -p "Masukkan pilihan [1-4]: " choice

case "$choice" in
    1)
        bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST" --force
        ;;
    2)
        bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5" --force
        ;;
    3)
        bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST"
        bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5"
        ;;
    *)
        echo "Selesai."
        ;;
esac
