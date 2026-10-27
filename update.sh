#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# AI Tools Updater for Termux (OpenCode & Antigravity CLI)
# Real-time GitHub Upstream Releases Checker
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

echo -e "\n${BOLD}${CYAN}=== Memeriksa Update AI Tools di Termux (Live GitHub) ===${RESET}\n"

# 1. Fetch releases live from GitHub anomalyco/opencode
log_info "Mengambil data rilis resmi langsung dari GitHub (anomalyco/opencode)..."
OPENCODE_RELEASES_JSON=$(curl -sL --max-time 15 "https://api.github.com/repos/anomalyco/opencode/releases?per_page=30" 2>/dev/null || echo "")

# Extract OpenCode v1 latest tag
OPENCODE_LATEST_TAG=$(echo "$OPENCODE_RELEASES_JSON" | grep '"tag_name":' | grep '"v1\.' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
OPENCODE_LATEST="${OPENCODE_LATEST_TAG#v}"
if [ -z "$OPENCODE_LATEST" ]; then
    OPENCODE_LATEST="1.19.4"
fi

# Extract OpenCode v2 latest tag
OPENCODE2_LATEST_TAG=$(echo "$OPENCODE_RELEASES_JSON" | grep '"tag_name":' | grep '"v2\.' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
OPENCODE2_LATEST="${OPENCODE2_LATEST_TAG#v}"
if [ -z "$OPENCODE2_LATEST" ]; then
    OPENCODE2_LATEST="2.2.0"
fi

# 2. Fetch releases live from GitHub google-antigravity/antigravity-cli
log_info "Mengambil data rilis resmi Antigravity CLI dari GitHub..."
AGY_LATEST_RAW=$(curl -sL --max-time 15 "https://api.github.com/repos/google-antigravity/antigravity-cli/releases/latest" 2>/dev/null | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "1.4.8")
AGY_LATEST="${AGY_LATEST_RAW#v}"
if [ -z "$AGY_LATEST" ]; then
    AGY_LATEST="1.4.8"
fi

# 3. Detect installed versions
OPENCODE_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/opencode" ]; then
    RAW_V1=$("$PREFIX/bin/opencode" --version 2>/dev/null || echo "Unknown")
    OPENCODE_INSTALLED=$(echo "$RAW_V1" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

OPENCODE2_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/opencode-v2" ]; then
    RAW_V2=$("$PREFIX/bin/opencode-v2" --version 2>/dev/null || echo "Unknown")
    OPENCODE2_INSTALLED=$(echo "$RAW_V2" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

AGY_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/agy" ]; then
    RAW_AGY=$("$PREFIX/bin/agy" --version 2>/dev/null || echo "Unknown")
    AGY_INSTALLED=$(echo "$RAW_AGY" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

# 4. Display recent upstream release tags from GitHub
if [ -n "$OPENCODE_RELEASES_JSON" ]; then
    echo -e "\n${BOLD}${CYAN}Rilis Terbaru di GitHub Upstream (anomalyco/opencode):${RESET}"
    echo "$OPENCODE_RELEASES_JSON" | grep '"tag_name":' | head -n 8 | sed -E 's/.*"([^"]+)".*/  • \1/'
fi

echo -e "\n${BOLD}Ringkasan Status di Termux Anda:${RESET}"
printf "%-18s | %-16s | %-16s | %-10s\n" "Software" "Terpasang" "Upstream" "Status"
echo "----------------------------------------------------------------------"

# OpenCode v1 status
if [ "$OPENCODE_INSTALLED" = "$OPENCODE_LATEST" ]; then
    OPENCODE_STATUS="${GREEN}Up-to-date${RESET}"
elif [ "$OPENCODE_INSTALLED" = "Tidak terpasang" ]; then
    OPENCODE_STATUS="${YELLOW}Belum ada${RESET}"
else
    OPENCODE_STATUS="${RED}Ada update! (${OPENCODE_LATEST})${RESET}"
fi
printf "%-18s | %-16s | %-16s | %-10b\n" "OpenCode v1" "$OPENCODE_INSTALLED" "$OPENCODE_LATEST" "$OPENCODE_STATUS"

# OpenCode v2 status
if [ "$OPENCODE2_INSTALLED" = "$OPENCODE2_LATEST" ]; then
    OPENCODE2_STATUS="${GREEN}Up-to-date${RESET}"
elif [ "$OPENCODE2_INSTALLED" = "Tidak terpasang" ]; then
    OPENCODE2_STATUS="${YELLOW}Belum ada${RESET}"
else
    OPENCODE2_STATUS="${RED}Ada update! (${OPENCODE2_LATEST})${RESET}"
fi
printf "%-18s | %-16s | %-16s | %-10b\n" "OpenCode v2" "$OPENCODE2_INSTALLED" "$OPENCODE2_LATEST" "$OPENCODE2_STATUS"

# AGY status (v1.3.5 build stabil memori Termux)
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
if [ "$TARGET" = "opencode" ] || [ "$TARGET" = "v1" ]; then
    log_info "Memulai update OpenCode v1 ke versi $OPENCODE_LATEST..."
    bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST" --force
    exit 0
elif [ "$TARGET" = "opencode-v2" ] || [ "$TARGET" = "v2" ]; then
    log_info "Memulai update OpenCode v2 ke versi $OPENCODE2_LATEST..."
    bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$OPENCODE2_LATEST" --force
    exit 0
elif [ "$TARGET" = "agy" ]; then
    log_info "Memulai update / reinstal Antigravity CLI (1.3.5 stabil)..."
    bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5" --force
    exit 0
elif [ "$TARGET" = "all" ]; then
    log_info "Mengupdate semua tools..."
    bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST"
    bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$OPENCODE2_LATEST"
    bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5"
    exit 0
fi

# Interactive prompt if no arguments
echo -e "${BOLD}Pilihan tindakan:${RESET}"
echo "1) Update OpenCode v1 ke versi terbaru ($OPENCODE_LATEST)"
echo "2) Update / Pasang OpenCode v2 ke versi terbaru ($OPENCODE2_LATEST)"
echo "3) Pasang / Reinstall Antigravity CLI (v1.3.5 stabil)"
echo "4) Update / Sinkronisasi Semua Tools"
echo "5) Keluar"
read -r -p "Masukkan pilihan [1-5]: " choice

case "$choice" in
    1)
        bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST" --force
        ;;
    2)
        bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$OPENCODE2_LATEST" --force
        ;;
    3)
        bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5" --force
        ;;
    4)
        bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST"
        bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$OPENCODE2_LATEST"
        bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5"
        ;;
    *)
        echo "Selesai."
        ;;
esac
