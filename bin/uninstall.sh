#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Uninstaller for OpenCode & Antigravity CLI in Termux
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"

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

remove_opencode_v1() {
    local purge="$1"
    log_info "Menghapus OpenCode v1..."
    
    # Hapus dari dpkg jika terdaftar
    if dpkg -l 2>/dev/null | grep -q "^ii  opencode "; then
        log_info "Menghapus paket deb 'opencode' via dpkg..."
        dpkg -r opencode 2>/dev/null || true
    fi

    rm -f "$PREFIX/bin/opencode"
    rm -rf "$PREFIX/share/opencode"
    log_ok "Biner dan file sistem OpenCode v1 berhasil dihapus."

    if [ "$purge" = "true" ]; then
        log_warn "Menghapus konfigurasi dan data user OpenCode..."
        rm -rf "$HOME_DIR/.config/opencode"
        rm -rf "$HOME_DIR/.local/share/opencode"
        rm -f "$HOME_DIR/opencode.jsonc"
        log_ok "Konfigurasi OpenCode berhasil dibersihkan."
    fi
}

remove_opencode_v2() {
    local purge="$1"
    log_info "Menghapus OpenCode v2..."

    if dpkg -l 2>/dev/null | grep -q "^ii  opencode-v2 "; then
        log_info "Menghapus paket deb 'opencode-v2' via dpkg..."
        dpkg -r opencode-v2 2>/dev/null || true
    fi

    rm -f "$PREFIX/bin/opencode-v2"
    rm -rf "$PREFIX/share/opencode-v2"
    log_ok "Biner dan file sistem OpenCode v2 berhasil dihapus."

    if [ "$purge" = "true" ]; then
        log_warn "Menghapus konfigurasi dan data user OpenCode v2..."
        rm -rf "$HOME_DIR/.config/opencode"
        rm -rf "$HOME_DIR/.local/share/opencode"
        rm -f "$HOME_DIR/opencode.jsonc"
        log_ok "Konfigurasi OpenCode berhasil dibersihkan."
    fi
}

remove_agy() {
    local purge="$1"
    log_info "Menghapus Antigravity CLI (agy)..."

    if dpkg -l 2>/dev/null | grep -q "^ii  antigravity-cli "; then
        log_info "Menghapus paket deb 'antigravity-cli' via dpkg..."
        dpkg -r antigravity-cli 2>/dev/null || true
    fi

    rm -f "$PREFIX/bin/agy"
    rm -rf "$PREFIX/share/antigravity-cli"
    log_ok "Biner dan file sistem Antigravity CLI berhasil dihapus."

    if [ "$purge" = "true" ]; then
        log_warn "Menghapus konfigurasi dan data user Antigravity..."
        rm -rf "$HOME_DIR/.gemini"
        log_ok "Konfigurasi Antigravity berhasil dibersihkan."
    fi
}

TARGET="$1"
PURGE_FLAG="false"

for arg in "$@"; do
    if [ "$arg" = "--purge" ] || [ "$arg" = "-p" ]; then
        PURGE_FLAG="true"
    fi
done

ask_purge() {
    if [ "$PURGE_FLAG" != "true" ]; then
        echo ""
        read -r -p "Hapus juga file konfigurasi, token OAuth, dan data sesi user? (y/N): " ans
        case "$ans" in
            [yY]|[yY][eE][sS])
                PURGE_FLAG="true"
                ;;
            *)
                PURGE_FLAG="false"
                ;;
        esac
    fi
}

case "$TARGET" in
    opencode|v1|--opencode)
        ask_purge
        remove_opencode_v1 "$PURGE_FLAG"
        ;;
    opencode-v2|v2|--opencode-v2)
        ask_purge
        remove_opencode_v2 "$PURGE_FLAG"
        ;;
    agy|antigravity|--agy)
        ask_purge
        remove_agy "$PURGE_FLAG"
        ;;
    all|--all)
        ask_purge
        remove_opencode_v1 "$PURGE_FLAG"
        remove_opencode_v2 "$PURGE_FLAG"
        remove_agy "$PURGE_FLAG"
        ;;
    *)
        echo -e "${BOLD}${RED}=== Menu Uninstall Termux AI Tools ===${RESET}"
        echo "1) Uninstall OpenCode v1"
        echo "2) Uninstall OpenCode v2"
        echo "3) Uninstall Antigravity CLI (agy)"
        echo "4) Uninstall Semua (OpenCode & AGY)"
        echo "5) Batal / Keluar"
        echo ""
        read -r -p "Pilihan Anda [1-5]: " opt
        case "$opt" in
            1)
                ask_purge
                remove_opencode_v1 "$PURGE_FLAG"
                ;;
            2)
                ask_purge
                remove_opencode_v2 "$PURGE_FLAG"
                ;;
            3)
                ask_purge
                remove_agy "$PURGE_FLAG"
                ;;
            4)
                ask_purge
                remove_opencode_v1 "$PURGE_FLAG"
                remove_opencode_v2 "$PURGE_FLAG"
                remove_agy "$PURGE_FLAG"
                ;;
            *)
                echo "Dibatalkan."
                exit 0
                ;;
        esac
        ;;
esac

log_ok "Operasi uninstall selesai."
