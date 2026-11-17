#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Restore Script for OpenCode & Antigravity CLI Configurations
# Supports Full Restore & Custom / Selective Component Restore
# ==============================================================================

HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
RED="\033[31m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err()  { echo -e "${RED}[ERROR]${RESET} $1"; }

show_usage() {
    cat << EOF
${BOLD}${CYAN}Termux AI Tools - Selective & Full Restore${RESET}

${BOLD}Penggunaan:${RESET}
  ai restore [file-backup.tar.gz] [opsi]

${BOLD}Opsi:${RESET}
  -f, --full              Restore semua komponen yang ada di arsip (termasuk riwayat --full)
  -o, --only <list>       Restore komponen tertentu (pisah koma), contoh: --only mcp,agy
  -s, --select <list>     Alias untuk --only
  -l, --list              Lihat isi & komponen yang tersedia di dalam arsip tanpa restore
  -y, --yes               Lewati konfirmasi (y/N)
  -h, --help              Tampilkan bantuan ini

${BOLD}Komponen yang tersedia untuk --only:${RESET}
  full        Semua komponen (sama dengan --full)
  agy         Antigravity CLI (~/.gemini: config, token, settings, plugins, skills)
  oc1         OpenCode v1 (~/opencode.jsonc, config, auth & storage)
  oc2         OpenCode v2 (~/.config/opencode, cli/service, plugins & auth)
  opencode    OpenCode v1 & v2 sekaligus
  mcp         Hanya konfigurasi MCP Servers (agy, opencode & ~/.mcp.json - mode merge)
  skills      Hanya Agent Skills (~/.agents & ~/.gemini/skills)
  agents      Hanya Subagents & Personas (opencode & agy agents)
  memory      Knowledge Memory / AI Brain (~/.local/share/termux-ai/memory.db)
  accounts    Multi-Account Registry (~/.config/termux-ai/accounts.json)
  aswap       Antigravity Swap (~/.local/share/antigravity-swap accounts & credentials)
  env         Antigravity Scope & Environment Profile (.termux_ai_env, .termux_authinfo)
  rules       Global AI Rules (AGENTS.md, GEMINI.md, CLAUDE.md, .mcp.json, dll)
  history     Riwayat Chat & Session DB dari backup --full (opencode.db & agy brain)

${BOLD}Contoh:${RESET}
  ai restore                                  # Pilih file & komponen secara interaktif
  ai restore backup.tar.gz --list             # Cek isi arsip backup
  ai restore backup.tar.gz --only mcp         # Restore MCP servers saja
  ai restore backup.tar.gz --only agy,mcp     # Restore Antigravity CLI & MCP saja
  ai restore backup.tar.gz --full --yes       # Full restore tanpa konfirmasi
EOF
}

BACKUP_FILE=""
MODE_FULL="false"
MODE_LIST="false"
AUTO_YES="false"
ONLY_RAW=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help|help)
            show_usage
            exit 0
            ;;
        -f|--full)
            MODE_FULL="true"
            shift
            ;;
        -l|--list)
            MODE_LIST="true"
            shift
            ;;
        -y|--yes)
            AUTO_YES="true"
            shift
            ;;
        -o|--only|-s|--select)
            if [ -z "${2:-}" ]; then
                log_err "Opsi $1 membutuhkan daftar komponen (contoh: --only mcp,agy)"
                exit 1
            fi
            ONLY_RAW="$2"
            shift 2
            ;;
        --only=*|--select=*)
            ONLY_RAW="${1#*=}"
            shift
            ;;
        -*)
            log_err "Opsi tidak dikenal: $1"
            echo "Jalankan 'ai restore --help' untuk melihat daftar opsi."
            exit 1
            ;;
        *)
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE="$1"
            else
                log_err "Argumen tidak dikenal: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# If no backup file specified, search for available backup files
if [ -z "$BACKUP_FILE" ]; then
    echo -e "\n${BOLD}${CYAN}=== Pencarian File Backup AI Tools ===${RESET}\n"

    FOUND_FILES=()
    for f in termux-ai-backup-*.tar.gz *.tar.gz /sdcard/Download/termux-ai-backup-*.tar.gz; do
        if [ -f "$f" ]; then
            FOUND_FILES+=("$f")
        fi
    done

    if [ ${#FOUND_FILES[@]} -eq 0 ]; then
        log_err "Tidak menemukan file backup (.tar.gz) di direktori ini atau di /sdcard/Download/."
        echo "Silakan jalankan: ai restore <path-ke-file-backup.tar.gz>"
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

STAGE_DIR=$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/ai-restore.XXXXXX")
trap 'rm -rf "$STAGE_DIR"' EXIT

log_info "Memeriksa arsip backup '$BACKUP_FILE'..."
tar -xzf "$BACKUP_FILE" -C "$STAGE_DIR"

# Helper: check if a tar archive contains at least one member matching an ERE pattern
tar_has_match() {
    local archive="$1"
    local pattern="$2"
    [ -f "$archive" ] || return 1
    tar -tzf "$archive" 2>/dev/null | grep -qE "$pattern"
}

# Helper: extract only members matching an ERE pattern from a tar archive
extract_tar_matching() {
    local archive="$1"
    local dest="$2"
    local pattern="$3"
    [ -f "$archive" ] || return 1
    local list_file
    list_file=$(mktemp "$STAGE_DIR/tarlist.XXXXXX")
    tar -tzf "$archive" 2>/dev/null | grep -E "$pattern" > "$list_file" || true
    if [ -s "$list_file" ]; then
        mkdir -p "$dest"
        tar -xzf "$archive" -C "$dest" -T "$list_file"
        rm -f "$list_file"
        return 0
    fi
    rm -f "$list_file"
    return 1
}

# Inspect available components in the backup archive
HAS_OPENCODE="false"
HAS_AGY="false"
HAS_MCP="false"
HAS_SKILLS="false"
HAS_AGENTS="false"
HAS_MEMORY="false"
HAS_ACCOUNTS="false"
HAS_ASWAP="false"
HAS_ENV="false"
HAS_RULES="false"
HAS_HISTORY="false"

[ -d "$STAGE_DIR/opencode" ] && HAS_OPENCODE="true"
[ -d "$STAGE_DIR/gemini" ] && HAS_AGY="true"
[ -d "$STAGE_DIR/memory" ] && HAS_MEMORY="true"
[ -d "$STAGE_DIR/termux_ai" ] && HAS_ACCOUNTS="true"
[ -d "$STAGE_DIR/aswap" ] && HAS_ASWAP="true"
[ -d "$STAGE_DIR/env" ] && HAS_ENV="true"
[ -d "$STAGE_DIR/rules" ] && HAS_RULES="true"

if tar_has_match "$STAGE_DIR/gemini/gemini_settings.tar.gz" '^\.?/?\.gemini/(config/mcp_config\.json|settings\.json)$' || \
   tar_has_match "$STAGE_DIR/opencode/config_opencode.tar.gz" '^\.?/?opencode/opencode\.jsonc?$' || \
   [ -f "$STAGE_DIR/opencode/opencode.jsonc" ] || \
   tar_has_match "$STAGE_DIR/rules/global_rules.tar.gz" '^\.?/?\.mcp\.json$'; then
    HAS_MCP="true"
fi

if [ -d "$STAGE_DIR/agents" ] || \
   tar_has_match "$STAGE_DIR/gemini/gemini_settings.tar.gz" '^\.?/?\.gemini/skills(-disabled)?(/|$)'; then
    HAS_SKILLS="true"
fi

if tar_has_match "$STAGE_DIR/opencode/config_opencode.tar.gz" '^\.?/?opencode/agents(/|$)' || \
   tar_has_match "$STAGE_DIR/gemini/gemini_settings.tar.gz" '^\.?/?\.gemini/config/agents(/|$)'; then
    HAS_AGENTS="true"
fi

if tar_has_match "$STAGE_DIR/opencode/share_opencode.tar.gz" '^\.?/?opencode/(opencode\.db|snapshot/|tool-output/)' || \
   tar_has_match "$STAGE_DIR/gemini/gemini_settings.tar.gz" '^\.?/?\.gemini/antigravity-cli/(brain|conversations)(/|$)'; then
    HAS_HISTORY="true"
fi

# Show archive metadata
echo -e "\n${BOLD}${CYAN}=== Informasi Arsip Backup ===${RESET}"
echo -e "  File       : ${BOLD}$BACKUP_FILE${RESET} ($(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1))"
if [ -f "$STAGE_DIR/metadata.json" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$STAGE_DIR/metadata.json" << 'EOF'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        meta = json.load(f)
    print(f"  Versi      : v{meta.get('backup_version', '?')}")
    print(f"  Dibuat     : {meta.get('created_at', '?')}")
    print(f"  User       : {meta.get('device_user', '?')}")
except Exception:
    pass
EOF
fi
if [ "$HAS_HISTORY" = "true" ]; then
    echo -e "  Tipe Arsip : ${GREEN}FULL BACKUP (--full)${RESET} ${DIM}(menyertakan riwayat chat & database sesi)${RESET}"
else
    echo -e "  Tipe Arsip : ${CYAN}STANDAR${RESET} ${DIM}(konfigurasi, token, skills, memory & rules)${RESET}"
fi

# Component availability helper
avail_badge() {
    if [ "$1" = "true" ]; then
        echo -e "${GREEN}[Tersedia]${RESET}"
    else
        echo -e "${DIM}[Tidak ada]${RESET}"
    fi
}

print_component_menu() {
    echo -e "\n${BOLD}${CYAN}=== Komponen yang Tersedia untuk Restore ===${RESET}"
    printf "  ${GREEN}%2s)${RESET} ${BOLD}%-26s${RESET} %s\n" "1" "[FULL] Semua Komponen" "$([ "$HAS_HISTORY" = "true" ] && echo "Semua config, token, skills & riwayat --full" || echo "Semua config, token, skills, memory & rules")"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "2" "Antigravity CLI (agy)" "$(avail_badge "$HAS_AGY")" "${DIM}~/.gemini (config, token, settings, skills)${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "3" "OpenCode v1 (oc)" "$(avail_badge "$HAS_OPENCODE")" "${DIM}~/opencode.jsonc, config, auth & storage${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "4" "OpenCode v2 (oc2)" "$(avail_badge "$HAS_OPENCODE")" "${DIM}~/.config/opencode, cli/service, auth & plugins${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "5" "MCP Servers Only" "$(avail_badge "$HAS_MCP")" "${DIM}Merge MCP config (agy, oc1, oc2, ~/.mcp.json)${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "6" "Agent Skills Only" "$(avail_badge "$HAS_SKILLS")" "${DIM}~/.agents & ~/.gemini/skills${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "7" "Subagents & Personas" "$(avail_badge "$HAS_AGENTS")" "${DIM}Agents OpenCode & Antigravity${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "8" "Knowledge Memory" "$(avail_badge "$HAS_MEMORY")" "${DIM}~/.local/share/termux-ai/memory.db${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "9" "Multi-Account Registry" "$(avail_badge "$HAS_ACCOUNTS")" "${DIM}~/.config/termux-ai/accounts.json${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "10" "Antigravity Swap (aswap)" "$(avail_badge "$HAS_ASWAP")" "${DIM}~/.local/share/antigravity-swap (accounts & creds)${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "11" "Env & Scope" "$(avail_badge "$HAS_ENV")" "${DIM}~/.config/antigravity, .termux_ai_env, authinfo${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "12" "Global AI Rules" "$(avail_badge "$HAS_RULES")" "${DIM}AGENTS.md, GEMINI.md, CLAUDE.md, .mcp.json${RESET}"
    printf "  ${CYAN}%2s)${RESET} ${BOLD}%-26s${RESET} %b %s\n" "13" "Riwayat Chat & DB (--full)" "$(avail_badge "$HAS_HISTORY")" "${DIM}opencode.db & agy brain/conversations${RESET}"
    echo -e "   ${YELLOW}0)${RESET} Batal"
}

if [ "$MODE_LIST" = "true" ]; then
    print_component_menu
    exit 0
fi

# Selection state
SEL_FULL="false"
SEL_AGY="false"
SEL_OC1="false"
SEL_OC2="false"
SEL_MCP="false"
SEL_SKILLS="false"
SEL_AGENTS="false"
SEL_MEMORY="false"
SEL_ACCOUNTS="false"
SEL_ASWAP="false"
SEL_ENV="false"
SEL_RULES="false"
SEL_HISTORY="false"

apply_selection_tokens() {
    local raw="$1"
    # Replace commas with spaces and lowercase
    local normalized
    normalized=$(echo "$raw" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')
    local any_valid="false"

    for tok in $normalized; do
        case "$tok" in
            1|full|all)
                SEL_FULL="true"
                any_valid="true"
                ;;
            2|agy|antigravity|gemini)
                SEL_AGY="true"
                any_valid="true"
                ;;
            3|oc1|oc-v1|opencode1|opencode-v1)
                SEL_OC1="true"
                any_valid="true"
                ;;
            4|oc2|oc-v2|opencode2|opencode-v2)
                SEL_OC2="true"
                any_valid="true"
                ;;
            opencode|oc)
                SEL_OC1="true"
                SEL_OC2="true"
                any_valid="true"
                ;;
            5|mcp)
                SEL_MCP="true"
                any_valid="true"
                ;;
            6|skills|skill)
                SEL_SKILLS="true"
                any_valid="true"
                ;;
            7|agents|agent|personas|persona)
                SEL_AGENTS="true"
                any_valid="true"
                ;;
            8|memory|mem|brain)
                SEL_MEMORY="true"
                any_valid="true"
                ;;
            9|accounts|account|acc)
                SEL_ACCOUNTS="true"
                any_valid="true"
                ;;
            10|aswap|swap|antigravity-swap)
                SEL_ASWAP="true"
                any_valid="true"
                ;;
            11|env|scope)
                SEL_ENV="true"
                any_valid="true"
                ;;
            12|rules|rule)
                SEL_RULES="true"
                any_valid="true"
                ;;
            13|history|sessions|session|db)
                SEL_HISTORY="true"
                any_valid="true"
                ;;
            0|q|quit|exit|batal)
                echo "Restore dibatalkan."
                exit 0
                ;;
            *)
                log_err "Pilihan tidak valid: '$tok'"
                return 1
                ;;
        esac
    done

    [ "$any_valid" = "true" ]
}

if [ "$MODE_FULL" = "true" ]; then
    SEL_FULL="true"
elif [ -n "$ONLY_RAW" ]; then
    apply_selection_tokens "$ONLY_RAW" || exit 1
else
    print_component_menu
    echo ""
    echo -e "${DIM}Tips: Bisa pilih lebih dari satu, pisahkan dengan koma atau spasi (contoh: 5 atau 2,4,5 atau agy,oc2,mcp)${RESET}"
    read -r -p "Pilih komponen yang akan di-restore [1-13, atau 0 batal]: " user_sel
    if [ -z "$user_sel" ]; then
        echo "Restore dibatalkan."
        exit 0
    fi
    apply_selection_tokens "$user_sel" || exit 1
fi

# Build summary of what will be restored
SELECTED_LABELS=()
if [ "$SEL_FULL" = "true" ]; then
    SELECTED_LABELS+=("FULL (Semua komponen yang tersedia di arsip)")
else
    [ "$SEL_AGY" = "true" ] && SELECTED_LABELS+=("Antigravity CLI (agy)")
    [ "$SEL_OC1" = "true" ] && SELECTED_LABELS+=("OpenCode v1 (oc)")
    [ "$SEL_OC2" = "true" ] && SELECTED_LABELS+=("OpenCode v2 (oc2)")
    [ "$SEL_MCP" = "true" ] && SELECTED_LABELS+=("MCP Servers Only (merge)")
    [ "$SEL_SKILLS" = "true" ] && SELECTED_LABELS+=("Agent Skills")
    [ "$SEL_AGENTS" = "true" ] && SELECTED_LABELS+=("Subagents & Personas")
    [ "$SEL_MEMORY" = "true" ] && SELECTED_LABELS+=("Knowledge Memory (AI Brain)")
    [ "$SEL_ACCOUNTS" = "true" ] && SELECTED_LABELS+=("Multi-Account Registry (~/.config/termux-ai)")
    [ "$SEL_ASWAP" = "true" ] && SELECTED_LABELS+=("Antigravity Swap (aswap)")
    [ "$SEL_ENV" = "true" ] && SELECTED_LABELS+=("Env & Scope")
    [ "$SEL_RULES" = "true" ] && SELECTED_LABELS+=("Global AI Rules")
    [ "$SEL_HISTORY" = "true" ] && SELECTED_LABELS+=("Riwayat Chat & Session DB (--full)")
fi

echo -e "\n${BOLD}${YELLOW}Ringkasan Restore:${RESET}"
for lbl in "${SELECTED_LABELS[@]}"; do
    echo -e "  ${CYAN}•${RESET} $lbl"
done

if [ "$AUTO_YES" != "true" ]; then
    echo -e "\n${BOLD}${YELLOW}Perhatian:${RESET} Proses restore akan menimpa/menggabungkan pengaturan yang dipilih."
    read -r -p "Lanjutkan proses restore? (y/N): " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS]) ;;
        *)
            echo "Restore dibatalkan."
            exit 0
            ;;
    esac
fi

echo ""

# ==============================================================================
# Individual Component Restore Functions
# ==============================================================================

restore_opencode() {
    local include_history="$1"
    if [ "$HAS_OPENCODE" != "true" ]; then
        log_warn "Data OpenCode tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan pengaturan OpenCode (v1 & v2)..."
    mkdir -p "$HOME_DIR/.config" "$HOME_DIR/.local/share"

    if [ -f "$STAGE_DIR/opencode/config_opencode.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/opencode/config_opencode.tar.gz" -C "$HOME_DIR/.config"
    fi
    if [ -f "$STAGE_DIR/opencode/share_opencode.tar.gz" ]; then
        if [ "$include_history" = "true" ]; then
            tar -xzf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share"
        else
            tar -xzf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share" \
                --exclude='opencode/opencode.db*' \
                --exclude='opencode/snapshot' \
                --exclude='opencode/tool-output'
        fi
    fi
    if [ -f "$STAGE_DIR/opencode/opencode.jsonc" ]; then
        cp "$STAGE_DIR/opencode/opencode.jsonc" "$HOME_DIR/"
    fi
    log_ok "Pengaturan OpenCode (v1 & v2) berhasil dipulihkan."
}

restore_opencode_v1() {
    local include_history="$1"
    if [ "$HAS_OPENCODE" != "true" ]; then
        log_warn "Data OpenCode v1 tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan pengaturan OpenCode v1 (oc)..."
    mkdir -p "$HOME_DIR/.config" "$HOME_DIR/.local/share"

    if [ -f "$STAGE_DIR/opencode/config_opencode.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/opencode/config_opencode.tar.gz" -C "$HOME_DIR/.config" \
            --exclude='opencode/cli.json' \
            --exclude='opencode/service.json'
    fi
    if [ -f "$STAGE_DIR/opencode/share_opencode.tar.gz" ]; then
        if [ "$include_history" = "true" ]; then
            tar -xzf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share"
        else
            tar -xzf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share" \
                --exclude='opencode/opencode.db*' \
                --exclude='opencode/snapshot' \
                --exclude='opencode/tool-output'
        fi
    fi
    if [ -f "$STAGE_DIR/opencode/opencode.jsonc" ]; then
        cp "$STAGE_DIR/opencode/opencode.jsonc" "$HOME_DIR/"
    fi
    log_ok "Pengaturan OpenCode v1 (oc) berhasil dipulihkan."
}

restore_opencode_v2() {
    local include_history="$1"
    if [ "$HAS_OPENCODE" != "true" ]; then
        log_warn "Data OpenCode v2 tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan pengaturan OpenCode v2 (oc2)..."
    mkdir -p "$HOME_DIR/.config" "$HOME_DIR/.local/share"

    if [ -f "$STAGE_DIR/opencode/config_opencode.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/opencode/config_opencode.tar.gz" -C "$HOME_DIR/.config"
    fi
    if [ -f "$STAGE_DIR/opencode/share_opencode.tar.gz" ]; then
        if [ "$include_history" = "true" ]; then
            tar -xzf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share" \
                --exclude='opencode/storage'
        else
            tar -xzf "$STAGE_DIR/opencode/share_opencode.tar.gz" -C "$HOME_DIR/.local/share" \
                --exclude='opencode/storage' \
                --exclude='opencode/opencode.db*' \
                --exclude='opencode/snapshot' \
                --exclude='opencode/tool-output'
        fi
    fi
    log_ok "Pengaturan OpenCode v2 (oc2) berhasil dipulihkan."
}

restore_agy() {
    local include_history="$1"
    if [ "$HAS_AGY" != "true" ]; then
        log_warn "Data Antigravity CLI (agy) tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan pengaturan & token Antigravity CLI (agy)..."
    if [ -f "$STAGE_DIR/gemini/gemini_settings.tar.gz" ]; then
        if [ "$include_history" = "true" ]; then
            tar -xzf "$STAGE_DIR/gemini/gemini_settings.tar.gz" -C "$HOME_DIR"
        else
            tar -xzf "$STAGE_DIR/gemini/gemini_settings.tar.gz" -C "$HOME_DIR" \
                --exclude='.gemini/antigravity-cli/brain' \
                --exclude='.gemini/antigravity-cli/conversations'
        fi
        if [ -f "$HOME_DIR/.gemini/antigravity-cli/antigravity-oauth-token" ]; then
            chmod 600 "$HOME_DIR/.gemini/antigravity-cli/antigravity-oauth-token"
        fi
    fi
    log_ok "Pengaturan Antigravity CLI (agy) berhasil dipulihkan."
}

restore_history() {
    if [ "$HAS_HISTORY" != "true" ]; then
        log_warn "Riwayat chat / database sesi (--full) tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan riwayat chat & database sesi (--full)..."
    local restored_any="false"
    if extract_tar_matching "$STAGE_DIR/opencode/share_opencode.tar.gz" "$HOME_DIR/.local/share" '^\.?/?opencode/(opencode\.db|snapshot/|tool-output/)'; then
        restored_any="true"
    fi
    if extract_tar_matching "$STAGE_DIR/gemini/gemini_settings.tar.gz" "$HOME_DIR" '^\.?/?\.gemini/antigravity-cli/(brain|conversations)(/|$)'; then
        restored_any="true"
    fi
    if [ "$restored_any" = "true" ]; then
        log_ok "Riwayat chat & database sesi (--full) berhasil dipulihkan."
    else
        log_warn "Tidak ada file riwayat yang diekstrak."
    fi
}

restore_mcp_only() {
    if [ "$HAS_MCP" != "true" ]; then
        log_warn "Konfigurasi MCP tidak ditemukan di arsip backup."
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        log_err "Python3 diperlukan untuk merge konfigurasi MCP secara aman."
        return 1
    fi

    log_info "Memulihkan & menggabungkan konfigurasi MCP Servers..."
    local mcp_tmp="$STAGE_DIR/_mcp_extract"
    mkdir -p "$mcp_tmp/gemini" "$mcp_tmp/opencode" "$mcp_tmp/rules"

    extract_tar_matching "$STAGE_DIR/gemini/gemini_settings.tar.gz" "$mcp_tmp/gemini" '^\.?/?\.gemini/(config/mcp_config\.json|settings\.json)$' || true
    extract_tar_matching "$STAGE_DIR/opencode/config_opencode.tar.gz" "$mcp_tmp/opencode" '^\.?/?opencode/opencode\.jsonc?$' || true
    if [ -f "$STAGE_DIR/opencode/opencode.jsonc" ]; then
        cp "$STAGE_DIR/opencode/opencode.jsonc" "$mcp_tmp/opencode/root_opencode.jsonc"
    fi
    extract_tar_matching "$STAGE_DIR/rules/global_rules.tar.gz" "$mcp_tmp/rules" '^\.?/?\.mcp\.json$' || true

    python3 - "$mcp_tmp" "$HOME_DIR" << 'EOF'
import json
import os
import re
import shutil
import sys

mcp_tmp = sys.argv[1]
home_dir = sys.argv[2]

def strip_jsonc(text):
    result = []
    i = 0
    in_string = False
    escape = False
    n = len(text)
    while i < n:
        c = text[i]
        if in_string:
            result.append(c)
            if escape:
                escape = False
            elif c == '\\':
                escape = True
            elif c == '"':
                in_string = False
            i += 1
        else:
            if c == '"':
                in_string = True
                result.append(c)
                i += 1
            elif c == '/' and i + 1 < n and text[i + 1] == '/':
                i += 2
                while i < n and text[i] != '\n':
                    i += 1
            elif c == '/' and i + 1 < n and text[i + 1] == '*':
                i += 2
                while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                    i += 1
                i += 2
            else:
                result.append(c)
                i += 1
    cleaned = ''.join(result)
    cleaned = re.sub(r',\s*([}\]])', r'\1', cleaned)
    return cleaned

def load_jsonc(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, 'r', encoding='utf-8') as f:
            raw = f.read().strip()
        if not raw:
            return {}
        return json.loads(strip_jsonc(raw))
    except Exception:
        return {}

def save_json_with_bak(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        shutil.copy2(path, path + ".bak")
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
        f.write('\n')

def merge_key(src_path, dst_path, key_name, label):
    if not os.path.exists(src_path):
        return 0
    src_data = load_jsonc(src_path)
    src_section = src_data.get(key_name)
    if not isinstance(src_section, dict) or not src_section:
        return 0
    dst_data = load_jsonc(dst_path)
    if not isinstance(dst_data.get(key_name), dict):
        dst_data[key_name] = {}
    dst_data[key_name].update(src_section)
    save_json_with_bak(dst_path, dst_data)
    print(f"  -> {label}: {len(src_section)} MCP server dipulihkan ke {dst_path}")
    return len(src_section)

total = 0
total += merge_key(
    os.path.join(mcp_tmp, "gemini/.gemini/config/mcp_config.json"),
    os.path.join(home_dir, ".gemini/config/mcp_config.json"),
    "mcpServers",
    "Antigravity mcp_config.json"
)
total += merge_key(
    os.path.join(mcp_tmp, "gemini/.gemini/settings.json"),
    os.path.join(home_dir, ".gemini/settings.json"),
    "mcpServers",
    "Antigravity settings.json"
)
total += merge_key(
    os.path.join(mcp_tmp, "opencode/opencode/opencode.jsonc"),
    os.path.join(home_dir, ".config/opencode/opencode.jsonc"),
    "mcp",
    "OpenCode ~/.config/opencode/opencode.jsonc"
)
total += merge_key(
    os.path.join(mcp_tmp, "opencode/opencode/opencode.json"),
    os.path.join(home_dir, ".config/opencode/opencode.json"),
    "mcp",
    "OpenCode ~/.config/opencode/opencode.json"
)
total += merge_key(
    os.path.join(mcp_tmp, "opencode/root_opencode.jsonc"),
    os.path.join(home_dir, "opencode.jsonc"),
    "mcp",
    "OpenCode ~/opencode.jsonc"
)
total += merge_key(
    os.path.join(mcp_tmp, "rules/.mcp.json"),
    os.path.join(home_dir, ".mcp.json"),
    "mcpServers",
    "Global ~/.mcp.json"
)
if total == 0:
    print("  -> Tidak ada entri MCP aktif yang ditemukan di file konfigurasi backup.")
EOF
    log_ok "Konfigurasi MCP Servers selesai diproses."
}

restore_skills_only() {
    if [ "$HAS_SKILLS" != "true" ]; then
        log_warn "Agent Skills tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan Agent Skills..."
    if [ -f "$STAGE_DIR/agents/agents_skills.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/agents/agents_skills.tar.gz" -C "$HOME_DIR"
    fi
    extract_tar_matching "$STAGE_DIR/gemini/gemini_settings.tar.gz" "$HOME_DIR" '^\.?/?\.gemini/skills(-disabled)?(/|$)' || true
    log_ok "Agent Skills (~/.agents & ~/.gemini/skills) berhasil dipulihkan."
}

restore_agents_only() {
    if [ "$HAS_AGENTS" != "true" ]; then
        log_warn "Subagents & Personas tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan Subagents & Personas..."
    mkdir -p "$HOME_DIR/.config"
    extract_tar_matching "$STAGE_DIR/opencode/config_opencode.tar.gz" "$HOME_DIR/.config" '^\.?/?opencode/agents(/|$)' || true
    extract_tar_matching "$STAGE_DIR/gemini/gemini_settings.tar.gz" "$HOME_DIR" '^\.?/?\.gemini/config/agents(/|$)' || true
    log_ok "Subagents & Personas berhasil dipulihkan."
}

restore_memory() {
    if [ "$HAS_MEMORY" != "true" ]; then
        log_warn "Knowledge Memory (AI Brain) tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan Knowledge Memory (AI Brain)..."
    mkdir -p "$HOME_DIR/.local/share"
    if [ -f "$STAGE_DIR/memory/termux_ai_memory.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/memory/termux_ai_memory.tar.gz" -C "$HOME_DIR/.local/share"
        chmod 700 "$HOME_DIR/.local/share/termux-ai" 2>/dev/null || true
        chmod 600 "$HOME_DIR/.local/share/termux-ai"/memory.db* 2>/dev/null || true
    fi
    log_ok "Knowledge Memory (memory.db) berhasil dipulihkan."
}

restore_accounts() {
    if [ "$HAS_ACCOUNTS" != "true" ]; then
        log_warn "Multi-Account Registry tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan Multi-Account Registry (~/.config/termux-ai)..."
    mkdir -p "$HOME_DIR/.config"
    if [ -f "$STAGE_DIR/termux_ai/termux_ai_config.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/termux_ai/termux_ai_config.tar.gz" -C "$HOME_DIR/.config"
        chmod 700 "$HOME_DIR/.config/termux-ai" 2>/dev/null || true
        chmod 600 "$HOME_DIR/.config/termux-ai/accounts.json" 2>/dev/null || true
    fi
    log_ok "Multi-Account Registry (accounts.json) berhasil dipulihkan."
}

restore_aswap() {
    if [ "$HAS_ASWAP" != "true" ]; then
        log_warn "Antigravity Swap (aswap) tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan Antigravity Swap (aswap)..."
    mkdir -p "$HOME_DIR/.local/share"
    if [ -f "$STAGE_DIR/aswap/antigravity_swap.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/aswap/antigravity_swap.tar.gz" -C "$HOME_DIR/.local/share"
        chmod 700 "$HOME_DIR/.local/share/antigravity-swap" 2>/dev/null || true
        [ -d "$HOME_DIR/.local/share/antigravity-swap/credentials" ] && chmod 700 "$HOME_DIR/.local/share/antigravity-swap/credentials" 2>/dev/null || true
        [ -f "$HOME_DIR/.local/share/antigravity-swap/accounts.json" ] && chmod 600 "$HOME_DIR/.local/share/antigravity-swap/accounts.json" 2>/dev/null || true
        find "$HOME_DIR/.local/share/antigravity-swap/credentials" -type f -exec chmod 600 {} + 2>/dev/null || true
    fi
    log_ok "Antigravity Swap (accounts & credentials) berhasil dipulihkan."
    if ! command -v aswap >/dev/null 2>&1; then
        if command -v pip >/dev/null 2>&1; then
            log_info "Binary 'aswap' belum terpasang. Menginstal otomatis via pip..."
            if pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"; then
                log_ok "antigravity-swap (aswap) berhasil diinstal."
            else
                log_warn "Gagal auto-install aswap (cek koneksi internet/git). Jalankan manual nanti: ai aswap"
            fi
        else
            log_warn "pip belum tersedia untuk auto-install aswap. Jalankan 'ai aswap' setelah memasang python-pip."
        fi
    fi
}

restore_env() {
    if [ "$HAS_ENV" != "true" ]; then
        log_warn "Antigravity Scope & Environment Profile tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan Antigravity Scope & Environment Profile..."
    if [ -f "$STAGE_DIR/env/antigravity_config.tar.gz" ]; then
        mkdir -p "$HOME_DIR/.config"
        tar -xzf "$STAGE_DIR/env/antigravity_config.tar.gz" -C "$HOME_DIR/.config"
    fi
    if [ -f "$STAGE_DIR/env/.termux_ai_env" ]; then
        cp "$STAGE_DIR/env/.termux_ai_env" "$HOME_DIR/"
        chmod 600 "$HOME_DIR/.termux_ai_env" 2>/dev/null || true
    fi
    if [ -f "$STAGE_DIR/env/.termux_authinfo" ]; then
        cp "$STAGE_DIR/env/.termux_authinfo" "$HOME_DIR/"
        chmod 600 "$HOME_DIR/.termux_authinfo" 2>/dev/null || true
    fi
    log_ok "Antigravity Scope & Environment Profile berhasil dipulihkan."
}

restore_rules() {
    if [ "$HAS_RULES" != "true" ]; then
        log_warn "Global AI Rules tidak ditemukan di arsip backup."
        return 0
    fi
    log_info "Memulihkan Global AI Rules & MCP config..."
    if [ -f "$STAGE_DIR/rules/global_rules.tar.gz" ]; then
        tar -xzf "$STAGE_DIR/rules/global_rules.tar.gz" -C "$HOME_DIR"
    fi
    log_ok "Global AI Rules & MCP config berhasil dipulihkan."
}

# ==============================================================================
# Execute Selected Restore Operations
# ==============================================================================

if [ "$SEL_FULL" = "true" ]; then
    [ "$HAS_OPENCODE" = "true" ] && restore_opencode "true"
    [ "$HAS_AGY" = "true" ] && restore_agy "true"
    [ "$HAS_MEMORY" = "true" ] && restore_memory
    [ -d "$STAGE_DIR/agents" ] && restore_skills_only
    [ "$HAS_ACCOUNTS" = "true" ] && restore_accounts
    [ "$HAS_ASWAP" = "true" ] && restore_aswap
    [ "$HAS_ENV" = "true" ] && restore_env
    [ "$HAS_RULES" = "true" ] && restore_rules
else
    ANY_OC="false"
    if [ "$SEL_OC1" = "true" ] && [ "$SEL_OC2" = "true" ]; then
        restore_opencode "$SEL_HISTORY"
        ANY_OC="true"
    elif [ "$SEL_OC1" = "true" ]; then
        restore_opencode_v1 "$SEL_HISTORY"
        ANY_OC="true"
    elif [ "$SEL_OC2" = "true" ]; then
        restore_opencode_v2 "$SEL_HISTORY"
        ANY_OC="true"
    fi
    [ "$SEL_AGY" = "true" ] && restore_agy "$SEL_HISTORY"
    [ "$SEL_HISTORY" = "true" ] && [ "$ANY_OC" != "true" ] && [ "$SEL_AGY" != "true" ] && restore_history
    if [ "$SEL_HISTORY" = "true" ]; then
        # Ensure history is restored even if only one of opencode/agy was selected
        [ "$ANY_OC" = "true" ] && [ "$SEL_AGY" != "true" ] && extract_tar_matching "$STAGE_DIR/gemini/gemini_settings.tar.gz" "$HOME_DIR" '^\.?/?\.gemini/antigravity-cli/(brain|conversations)(/|$)' >/dev/null 2>&1 || true
        [ "$SEL_AGY" = "true" ] && [ "$ANY_OC" != "true" ] && extract_tar_matching "$STAGE_DIR/opencode/share_opencode.tar.gz" "$HOME_DIR/.local/share" '^\.?/?opencode/(opencode\.db|snapshot/|tool-output/)' >/dev/null 2>&1 || true
    fi
    [ "$SEL_MCP" = "true" ] && restore_mcp_only
    [ "$SEL_SKILLS" = "true" ] && [ "$SEL_AGY" != "true" ] && restore_skills_only
    [ "$SEL_SKILLS" = "true" ] && [ "$SEL_AGY" = "true" ] && [ -f "$STAGE_DIR/agents/agents_skills.tar.gz" ] && tar -xzf "$STAGE_DIR/agents/agents_skills.tar.gz" -C "$HOME_DIR" && log_ok "Universal Agent Skills (~/.agents) berhasil dipulihkan."
    [ "$SEL_AGENTS" = "true" ] && [ "$ANY_OC" != "true" ] && [ "$SEL_AGY" != "true" ] && restore_agents_only
    [ "$SEL_MEMORY" = "true" ] && restore_memory
    [ "$SEL_ACCOUNTS" = "true" ] && restore_accounts
    [ "$SEL_ASWAP" = "true" ] && restore_aswap
    [ "$SEL_ENV" = "true" ] && restore_env
    [ "$SEL_RULES" = "true" ] && restore_rules
fi

echo -e "\n${BOLD}${GREEN}✅ Restore Selesai! Komponen terpilih telah berhasil dipulihkan.${RESET}\n"
