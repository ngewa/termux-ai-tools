#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Export / Backup Script for OpenCode & Antigravity CLI Configurations
# ==============================================================================

HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEFAULT_BACKUP_NAME="termux-ai-backup-${TIMESTAMP}.tar.gz"

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

FULL_BACKUP="false"
OUTPUT_PATH=""

for arg in "$@"; do
    if [ "$arg" = "--full" ] || [ "$arg" = "-f" ]; then
        FULL_BACKUP="true"
    elif [ -z "$OUTPUT_PATH" ]; then
        OUTPUT_PATH="$arg"
    fi
done

if [ -z "$OUTPUT_PATH" ]; then
    OUTPUT_PATH="$DEFAULT_BACKUP_NAME"
fi

# Resolve to absolute path if relative
if [[ "$OUTPUT_PATH" != /* ]]; then
    OUTPUT_PATH="$(pwd)/$OUTPUT_PATH"
fi
mkdir -p "$(dirname "$OUTPUT_PATH")"

# Temporary staging area
STAGE_DIR=$(mktemp -d "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/ai-backup.XXXXXX")
trap 'rm -rf "$STAGE_DIR"' EXIT

echo -e "\n${BOLD}${CYAN}=== Export / Backup Pengaturan AI Tools ===${RESET}\n"

ITEMS_COUNT=0

# 1. Backup OpenCode Configurations
if [ -d "$HOME_DIR/.config/opencode" ] || [ -f "$HOME_DIR/opencode.jsonc" ] || [ -f "$HOME_DIR/.local/share/opencode/auth.json" ]; then
    log_info "Mengamankan konfigurasi OpenCode..."
    mkdir -p "$STAGE_DIR/opencode"
    if [ -d "$HOME_DIR/.config/opencode" ]; then
        # Exclude node_modules to keep backup lightweight
        tar -czf "$STAGE_DIR/opencode/config_opencode.tar.gz" -C "$HOME_DIR/.config" --exclude='opencode/node_modules' opencode 2>/dev/null || true
        ITEMS_COUNT=$((ITEMS_COUNT + 1))
    fi
    if [ -f "$HOME_DIR/opencode.jsonc" ]; then
        cp "$HOME_DIR/opencode.jsonc" "$STAGE_DIR/opencode/"
        ITEMS_COUNT=$((ITEMS_COUNT + 1))
    fi
    if [ -d "$HOME_DIR/.local/share/opencode" ]; then
        if [ "$FULL_BACKUP" = "true" ]; then
            log_info "Menyertakan database sesi penuh OpenCode (--full)..."
            tar -czf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share" --exclude='opencode/log' opencode 2>/dev/null || true
        else
            # Save only auth.json, plans, and storage configs (without 1.4GB opencode.db)
            tar -czf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share" \
                --exclude='opencode/opencode.db*' \
                --exclude='opencode/log' \
                --exclude='opencode/snapshot' \
                --exclude='opencode/tool-output' \
                opencode 2>/dev/null || true
        fi
        ITEMS_COUNT=$((ITEMS_COUNT + 1))
    fi
    log_ok "Konfigurasi OpenCode berhasil dikemas."
else
    log_warn "Tidak ada konfigurasi OpenCode yang ditemukan."
fi

# 2. Backup Antigravity CLI Configurations
if [ -d "$HOME_DIR/.gemini" ]; then
    log_info "Mengamankan konfigurasi & token Antigravity CLI..."
    mkdir -p "$STAGE_DIR/gemini"
    if [ "$FULL_BACKUP" = "true" ]; then
        log_info "Menyertakan riwayat percakapan & brain Antigravity (--full)..."
        tar -czf "$STAGE_DIR/gemini/gemini_settings.tar.gz" -C "$HOME_DIR" \
            --exclude='.gemini/antigravity-cli/bin' \
            --exclude='.gemini/antigravity-cli/cache' \
            --exclude='.gemini/antigravity-cli/log' \
            --exclude='.gemini/antigravity-cli/crashes' \
            .gemini 2>/dev/null || true
    else
        # Essential settings, credentials, skills, hooks, plugins only
        tar -czf "$STAGE_DIR/gemini/gemini_settings.tar.gz" -C "$HOME_DIR" \
            --exclude='.gemini/antigravity-cli/brain' \
            --exclude='.gemini/antigravity-cli/conversations' \
            --exclude='.gemini/antigravity-cli/bin' \
            --exclude='.gemini/antigravity-cli/cache' \
            --exclude='.gemini/antigravity-cli/log' \
            --exclude='.gemini/antigravity-cli/crashes' \
            .gemini 2>/dev/null || true
    fi
    ITEMS_COUNT=$((ITEMS_COUNT + 1))
    log_ok "Konfigurasi Antigravity CLI (settings, skills, plugins & token) berhasil dikemas."
else
    log_warn "Tidak ada konfigurasi Antigravity CLI (~/.gemini) yang ditemukan."
fi

# 3. Backup Knowledge Memory (AI Brain)
if [ -d "$HOME_DIR/.local/share/termux-ai" ]; then
    log_info "Mengamankan Knowledge Memory (AI Brain: memory.db)..."
    mkdir -p "$STAGE_DIR/memory"
    tar -czf "$STAGE_DIR/memory/termux_ai_memory.tar.gz" -C "$HOME_DIR/.local/share" termux-ai 2>/dev/null || true
    ITEMS_COUNT=$((ITEMS_COUNT + 1))
    log_ok "Knowledge Memory (memory.db) berhasil dikemas."
fi

# 4. Backup Universal Agent Skills (~/.agents)
if [ -d "$HOME_DIR/.agents" ]; then
    log_info "Mengamankan Universal Agent Skills (~/.agents)..."
    mkdir -p "$STAGE_DIR/agents"
    tar -czf "$STAGE_DIR/agents/agents_skills.tar.gz" -C "$HOME_DIR" .agents 2>/dev/null || true
    ITEMS_COUNT=$((ITEMS_COUNT + 1))
    log_ok "Universal Agent Skills (~/.agents) berhasil dikemas."
fi

if [ "$ITEMS_COUNT" -eq 0 ]; then
    log_err "Tidak ada file konfigurasi yang ditemukan untuk diexport!"
    exit 1
fi

# 5. Create metadata file
cat > "$STAGE_DIR/metadata.json" << EOF
{
  "backup_version": "1.2",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "device_user": "$(whoami 2>/dev/null || echo 'termux')",
  "packages": ["opencode", "antigravity-cli", "termux-ai-memory", "agent-skills"]
}
EOF

# 6. Create final backup archive
log_info "Membuat arsip final backup: $OUTPUT_PATH..."
tar -czf "$OUTPUT_PATH" -C "$STAGE_DIR" .

FILE_SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
log_ok "Backup berhasil dibuat: $OUTPUT_PATH (${FILE_SIZE})"

# 5. Copy to /sdcard/Download if accessible for safety
SDCARD_DOWNLOAD="/sdcard/Download"
if [ -d "$SDCARD_DOWNLOAD" ] && [ -w "$SDCARD_DOWNLOAD" ]; then
    BACKUP_SDCARD="$SDCARD_DOWNLOAD/$(basename "$OUTPUT_PATH")"
    cp "$OUTPUT_PATH" "$BACKUP_SDCARD" 2>/dev/null || true
    log_info "Salinan backup juga disimpan di: ${BOLD}${BACKUP_SDCARD}${RESET}"
fi

echo -e "\n${BOLD}${GREEN}✅ Export Selesai! Simpan file arsip ini untuk restore sewaktu-waktu.${RESET}\n"
