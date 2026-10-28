#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Universal Installer & CLI for Termux AI Tools (OpenCode & Antigravity CLI)
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

REPO_RAW_URL="https://raw.githubusercontent.com/ngewa/termux-ai-tools/main"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

# Find script directory if cloned locally
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

get_script() {
    local script_name="$1"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$script_name" ]; then
        echo "$SCRIPT_DIR/$script_name"
    else
        local tmp_script="${TMPDIR:-$PREFIX/tmp}/$(basename "$script_name")"
        curl -fsSL "$REPO_RAW_URL/$script_name" -o "$tmp_script"
        chmod +x "$tmp_script"
        echo "$tmp_script"
    fi
}

echo -e "${BOLD}${CYAN}"
echo "=================================================="
echo "      Termux AI Tools Installer & Updater        "
echo "  OpenCode v1, OpenCode v2 & Antigravity (agy)   "
echo "=================================================="
echo -e "${RESET}"

show_menu() {
    echo -e "${BOLD}Pilih opsi:${RESET}"
    echo -e "  ${GREEN}1)${RESET} Install / Update OpenCode v1 (Latest v1.19.4)"
    echo -e "  ${GREEN}2)${RESET} Install / Update OpenCode v2 (Latest upstream v2.2.0)"
    echo -e "  ${GREEN}3)${RESET} Install / Update Antigravity CLI (agy v1.3.5 stabil)"
    echo -e "  ${GREEN}4)${RESET} Install / Update Semua Tools"
    echo -e "  ${GREEN}5)${RESET} Cek Status & Versi Terpasang"
    echo -e "  ${CYAN}6)${RESET} Wizard Setup Provider & API Key (config.sh)"
    echo -e "  ${CYAN}7)${RESET} Manajemen Sesi & Optimasi DB Storage (session.sh)"
    echo -e "  ${CYAN}8)${RESET} Plugin & MCP Tool Installer (plugin.sh)"
    echo -e "  ${CYAN}9)${RESET} Diagnostik & Health Check Lingkungan (Doctor)"
    echo -e "  ${CYAN}10)${RESET} Export (Backup) Pengaturan & Token ke Arsip (.tar.gz)"
    echo -e "  ${CYAN}11)${RESET} Restore Pengaturan dari File Backup"
    echo -e "  ${CYAN}12)${RESET} Manajemen Background Web Service (service.sh)"
    echo -e "  ${GREEN}13)${RESET} Pasang Shortcut Cepat (Perintah 'ai', widget, aliases)"
    echo -e "  ${RED}14)${RESET} Uninstall Tools (Hapus biner / data)"
    echo -e "  ${YELLOW}15)${RESET} Keluar"
    echo ""
    read -r -p "Pilihan Anda [1-15]: " opt
    case "$opt" in
        1)
            local s
            s=$(get_script "bin/install-opencode.sh")
            bash "$s"
            ;;
        2)
            local s
            s=$(get_script "bin/install-opencode-v2.sh")
            bash "$s"
            ;;
        3)
            local s
            s=$(get_script "bin/install-agy.sh")
            bash "$s"
            ;;
        4)
            local s1 s2 s3
            s1=$(get_script "bin/install-opencode.sh")
            s2=$(get_script "bin/install-opencode-v2.sh")
            s3=$(get_script "bin/install-agy.sh")
            bash "$s1"
            bash "$s2"
            bash "$s3"
            ;;
        5)
            local s
            s=$(get_script "update.sh")
            bash "$s"
            ;;
        6)
            local s
            s=$(get_script "bin/config-helper.sh")
            bash "$s"
            ;;
        7)
            local s
            s=$(get_script "bin/session-manager.sh")
            bash "$s"
            ;;
        8)
            local s
            s=$(get_script "bin/plugin-installer.sh")
            bash "$s"
            ;;
        9)
            local s
            s=$(get_script "bin/doctor.sh")
            bash "$s"
            ;;
        10)
            local s
            s=$(get_script "bin/export-config.sh")
            bash "$s"
            ;;
        11)
            local s
            s=$(get_script "bin/restore-config.sh")
            bash "$s"
            ;;
        12)
            local s
            s=$(get_script "bin/service.sh")
            bash "$s"
            ;;
        13)
            local s
            s=$(get_script "bin/setup-shortcuts.sh")
            bash "$s"
            ;;
        14)
            local s
            s=$(get_script "bin/uninstall.sh")
            bash "$s"
            ;;
        15)
            echo "Keluar."
            exit 0
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid!${RESET}"
            ;;
    esac
}

# Process command-line flags
case "$1" in
    opencode|--opencode|v1|--v1)
        s=$(get_script "bin/install-opencode.sh")
        bash "$s" "$2"
        ;;
    opencode-v2|--opencode-v2|v2|--v2)
        s=$(get_script "bin/install-opencode-v2.sh")
        bash "$s" "$2"
        ;;
    agy|--agy)
        s=$(get_script "bin/install-agy.sh")
        bash "$s" "$2"
        ;;
    all|--all)
        s1=$(get_script "bin/install-opencode.sh")
        s2=$(get_script "bin/install-opencode-v2.sh")
        s3=$(get_script "bin/install-agy.sh")
        bash "$s1"
        bash "$s2"
        bash "$s3"
        ;;
    check|update|--check)
        s=$(get_script "update.sh")
        bash "$s"
        ;;
    config|cfg|--config)
        s=$(get_script "bin/config-helper.sh")
        shift
        bash "$s" "$@"
        ;;
    session|sess|--session)
        s=$(get_script "bin/session-manager.sh")
        shift
        bash "$s" "$@"
        ;;
    plugin|mcp|--plugin)
        s=$(get_script "bin/plugin-installer.sh")
        shift
        bash "$s" "$@"
        ;;
    doctor|--doctor)
        s=$(get_script "bin/doctor.sh")
        shift
        bash "$s" "$@"
        ;;
    service|web|--service)
        s=$(get_script "bin/service.sh")
        shift
        bash "$s" "$@"
        ;;
    shortcuts|shortcut|--shortcuts)
        s=$(get_script "bin/setup-shortcuts.sh")
        shift
        bash "$s" "$@"
        ;;
    export|backup|--export)
        s=$(get_script "bin/export-config.sh")
        shift
        bash "$s" "$@"
        ;;
    restore|--restore)
        s=$(get_script "bin/restore-config.sh")
        shift
        bash "$s" "$@"
        ;;
    uninstall|--uninstall)
        s=$(get_script "bin/uninstall.sh")
        shift
        bash "$s" "$@"
        ;;
    *)
        show_menu
        ;;
esac





