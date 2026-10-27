#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Restore Script for OpenCode & Antigravity CLI Configurations
# ==============================================================================

HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
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

BACKUP_FILE="$1"

# If no backup file specified, search for available backup files
if [ -z "$BACKUP_FILE" ]; then
    echo -e "\n${BOLD}${CYAN}=== Pencarian File Backup AI Tools ===${RESET}\n"
    
    FOUND_FILES=()
    # Search in current directory and /sdcard/Download
    for f in termux-ai-backup-*.tar.gz *.tar.gz /sdcard/Download/termux-ai-backup-*.tar.gz; do
        if [ -f "$f" ]; then
            FOUND_FILES+=("$f")
        fi
    done

    if [ ${#FOUND_FILES[@]} -eq 0 ]; then
        log_err "Tidak menemukan file backup (.tar.gz) di direktori ini atau di /sdcard/Download/."
        echo "Silakan jalankan: ./restore-config.sh <path-ke-file-backup.tar.gz>"
        exit 1
    fi

    echo "Pilih file backup yang ingin di-restore:"
    idx=1
    for f in "${FOUND_FILES[@]}"; do
        echo "  $idx) $f ($(du -h "$f" 2>/dev/null | cut -f1))"
        idx=$((idx + 1))
    done
    echo "  0) Batal"
    echo ""
    read -r -p "Pilihan Anda [1-${#FOUND_FILES[@]}]: " choice

    if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "${#FOUND_FILES[@]}" ] 2>/dev/null; then
        BACKUP_FILE="${FOUND_FILES[$((choice - 1))]}"
    else
        echo "Dibatalkan."
        exit 0
    fi
fi

if [ ! -f "$BACKUP_FILE" ]; then
    log_err "File backup tidak ditemukan: $BACKUP_FILE"
    exit 1
fi

echo -e "\n${BOLD}${YELLOW}Perhatian:${RESET} Proses restore akan menimpa pengaturan yang ada."
read -r -p "Lanjutkan proses restore dari '$BACKUP_FILE'? (y/N): " confirm
case "$confirm" in
    [yY]|[yY][eE][sS]) ;;
    *)
        echo "Restore dibatalkan."
        exit 0
        ;;
esac

STAGE_DIR=$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/ai-restore.XXXXXX")
trap 'rm -rf "$STAGE_DIR"' EXIT

log_info "Mengekstrak arsip backup..."
tar -xzf "$BACKUP_FILE" -C "$STAGE_DIR"

# 1. Restore OpenCode
if [ -d "$STAGE_DIR/opencode" ]; then
    log_info "Memulihkan pengaturan OpenCode..."
    mkdir -p "$HOME_DIR/.config" "$HOME_DIR/.local/share"
    
    if [ -f "$STAGE_DIR/opencode/config_opencode.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/opencode/config_opencode.tar.gz" -C "$HOME_DIR/.config"
    fi
    if [ -f "$STAGE_DIR/opencode/share_opencode.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share"
    fi
    if [ -f "$STAGE_DIR/opencode/opencode.jsonc" ]; then
        cp "$STAGE_DIR/opencode/opencode.jsonc" "$HOME_DIR/"
    fi
    log_ok "Pengaturan OpenCode berhasil dipulihkan."
fi

# 2. Restore Antigravity CLI
if [ -d "$STAGE_DIR/gemini" ]; then
    log_info "Memulihkan pengaturan & token Antigravity CLI..."
    if [ -f "$STAGE_DIR/gemini/gemini_settings.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/gemini/gemini_settings.tar.gz" -C "$HOME_DIR"
        # Secure OAuth token permissions if present
        if [ -f "$HOME_DIR/.gemini/antigravity-cli/antigravity-oauth-token" ]; then
            chmod 600 "$HOME_DIR/.gemini/antigravity-cli/antigravity-oauth-token"
        fi
    fi
    log_ok "Pengaturan Antigravity CLI berhasil dipulihkan."
fi

echo -e "\n${BOLD}${GREEN}✅ Restore Berhasil! Semua pengaturan dan token telah dipulihkan.${RESET}\n"
