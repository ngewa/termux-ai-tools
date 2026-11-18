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
DIM="\033[2m"
RESET="\033[0m"

# Detect local repo directory only when executed as a file (not piped via curl | bash)
SCRIPT_DIR=""
IS_PIPED=true
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
    IS_PIPED=false
fi

get_script() {
    local script_name="$1"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$script_name" ]; then
        echo "$SCRIPT_DIR/$script_name"
    else
        local tmp_script="${TMPDIR:-$PREFIX/tmp}/termux-ai-$(basename "$script_name")"
        curl -fsSL "$REPO_RAW_URL/$script_name" -o "$tmp_script"
        chmod +x "$tmp_script"
        echo "$tmp_script"
    fi
}

run_script() {
    local script_name="$1"
    shift
    local s
    s=$(get_script "$script_name")
    if [ "$IS_PIPED" = "true" ] && [ ! -t 0 ] && ( : </dev/tty ) 2>/dev/null; then
        bash "$s" "$@" </dev/tty
    else
        bash "$s" "$@"
    fi
}

prompt_read() {
    local prompt_text="$1"
    local var_name="$2"
    if [ -t 0 ]; then
        read -r -p "$prompt_text" "$var_name" || true
    elif [ "$IS_PIPED" = "true" ] && ( : </dev/tty ) 2>/dev/null; then
        read -r -p "$prompt_text" "$var_name" </dev/tty || true
    else
        read -r -p "$prompt_text" "$var_name" || true
    fi
}

install_aswap() {
    if ! command -v pip >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${RESET} pip belum terpasang. Jalankan: pkg install python-pip -y"
        exit 1
    fi
    pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
}

detect_tool_status() {
    local bin_path="$1"
    local sed_prefix="$2"
    if [ -x "$bin_path" ]; then
        local v
        v="$("$bin_path" --version 2>/dev/null | head -n1 | sed -e "s/^${sed_prefix} //" -e 's/^[vV]//')"
        if [ -n "$v" ]; then
            echo "${CYAN}(v${v})${RESET}"
        else
            echo "${CYAN}(Terpasang)${RESET}"
        fi
    else
        echo "${DIM}[Belum terpasang]${RESET}"
    fi
}

show_menu() {
    local v1_ver v2_ver agy_ver aswap_ver
    v1_ver="$(detect_tool_status "$PREFIX/bin/opencode" "opencode")"
    v2_ver="$(detect_tool_status "$PREFIX/bin/opencode-v2" "opencode")"
    agy_ver="$(detect_tool_status "$PREFIX/bin/agy" "antigravity")"
    if command -v aswap >/dev/null 2>&1; then
        aswap_ver="${CYAN}(Terpasang)${RESET}"
    else
        aswap_ver="${DIM}[Belum terpasang]${RESET}"
    fi

    clear 2>/dev/null || true
    echo -e "${BOLD}${CYAN}╭────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${BOLD}${CYAN}│      ⚡ Termux AI Tools Installer & Manager            │${RESET}"
    echo -e "${BOLD}${CYAN}│          ${DIM}Unified AI Ecosystem for Termux${RESET}${BOLD}${CYAN}               │${RESET}"
    echo -e "${BOLD}${CYAN}╰────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    echo -e " ${BOLD}${YELLOW}▸ Instalasi & Pembaruan Tools${RESET}"
    printf "   ${GREEN}%2s)${RESET} ${BOLD}%-24s${RESET} %b\n" "1" "OpenCode v1" "${v1_ver}"
    printf "   ${GREEN}%2s)${RESET} ${BOLD}%-24s${RESET} %b\n" "2" "OpenCode v2" "${v2_ver}"
    printf "   ${GREEN}%2s)${RESET} ${BOLD}%-24s${RESET} %b\n" "3" "Antigravity CLI (agy)" "${agy_ver}"
    printf "   ${GREEN}%2s)${RESET} ${BOLD}%-24s${RESET} %b\n" "4" "Antigravity Swap (aswap)" "${aswap_ver}"
    printf "   ${GREEN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "5" "Install / Update Semua" "(v1, v2 & agy sekaligus)"
    printf "   ${GREEN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "6" "Cek Update & Versi Live" "(Rilis GitHub & switcher)"
    echo ""

    echo -e " ${BOLD}${YELLOW}▸ AI Brain & Agent Extensions${RESET}"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "7" "AI Agent Skills" "(Prompt Master, Antislop, UI/UX)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "8" "Subagents & Personas" "(Roblox, Toolkit, Reverser)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "9" "Knowledge Memory" "(AI Brain terverifikasi & FTS5)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "10" "Plugin & MCP Tools" "(Termux device, bridge & API)"
    echo ""

    echo -e " ${BOLD}${YELLOW}▸ Akun, Kuota & Statistik${RESET}"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "11" "Multi-Account & Pool" "(Rotasi akun, kuota & aswap)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "12" "Usage Statistics" "(Token, request & pemakaian)"
    echo ""

    echo -e " ${BOLD}${YELLOW}▸ Konfigurasi & Pemeliharaan${RESET}"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "13" "Konfigurasi AI & Key" "(Setup API key & default model)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "14" "Manajemen Sesi & DB" "(Cari riwayat, ekspor & vacuum)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "15" "Background Web Service" "(Daemon web UI OpenCode)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "16" "Diagnostik Sistem" "(Doctor & health check)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "17" "Backup Pengaturan" "(Export settings & token .tar.gz)"
    printf "   ${CYAN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "18" "Restore Pengaturan" "(Restore data dari file backup)"
    printf "   ${GREEN}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "19" "Pasang Shortcut Cepat" "(Perintah 'ai', widget, aliases)"
    printf "   ${RED}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "20" "Uninstall Tools" "(Hapus biner / data)"
    echo ""

    printf "   ${YELLOW}%2s)${RESET} ${BOLD}%-24s${RESET} ${DIM}%s${RESET}\n" "0" "Keluar" "(atau ketik q / exit)"
    echo ""

    local opt=""
    prompt_read "Masukkan pilihan [0-20]: " opt
    case "$opt" in
        1)  run_script "bin/install-opencode.sh" ;;
        2)  run_script "bin/install-opencode-v2.sh" ;;
        3)  run_script "bin/install-agy.sh" ;;
        4)  install_aswap ;;
        5)
            run_script "bin/install-opencode.sh"
            run_script "bin/install-opencode-v2.sh"
            run_script "bin/install-agy.sh"
            ;;
        6)  run_script "update.sh" ;;
        7)  run_script "bin/skill-manager.sh" ;;
        8)  run_script "bin/agent-manager.sh" ;;
        9)  run_script "bin/memory-manager.sh" ;;
        10) run_script "bin/plugin-installer.sh" ;;
        11) run_script "bin/account-manager.sh" ;;
        12) run_script "bin/usage-stats.sh" ;;
        13) run_script "bin/config-helper.sh" ;;
        14) run_script "bin/session-manager.sh" ;;
        15) run_script "bin/service.sh" ;;
        16) run_script "bin/doctor.sh" ;;
        17) run_script "bin/export-config.sh" ;;
        18) run_script "bin/restore-config.sh" ;;
        19) run_script "bin/setup-shortcuts.sh" ;;
        20) run_script "bin/uninstall.sh" ;;
        0|q|Q|quit|exit|x|"")
            echo -e "${CYAN}Keluar.${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Pilihan '$opt' tidak valid!${RESET}"
            exit 1
            ;;
    esac
}

# Process command-line flags
case "${1:-}" in
    opencode|--opencode|v1|--v1)
        shift
        run_script "bin/install-opencode.sh" "$@"
        ;;
    opencode-v2|--opencode-v2|v2|--v2)
        shift
        run_script "bin/install-opencode-v2.sh" "$@"
        ;;
    agy|--agy)
        shift
        run_script "bin/install-agy.sh" "$@"
        ;;
    all|--all)
        run_script "bin/install-opencode.sh"
        run_script "bin/install-opencode-v2.sh"
        run_script "bin/install-agy.sh"
        ;;
    check|update|--check|--update)
        shift
        run_script "update.sh" "$@"
        ;;
    config|cfg|--config)
        shift
        run_script "bin/config-helper.sh" "$@"
        ;;
    session|sess|--session)
        shift
        run_script "bin/session-manager.sh" "$@"
        ;;
    plugin|mcp|--plugin)
        shift
        run_script "bin/plugin-installer.sh" "$@"
        ;;
    memory|mem|--memory)
        shift
        run_script "bin/memory-manager.sh" "$@"
        ;;
    skill|skills|--skill)
        shift
        run_script "bin/skill-manager.sh" "$@"
        ;;
    agent|agents|--agent)
        shift
        run_script "bin/agent-manager.sh" "$@"
        ;;
    doctor|--doctor)
        shift
        run_script "bin/doctor.sh" "$@"
        ;;
    account|acc|auth|--account)
        shift
        run_script "bin/account-manager.sh" "$@"
        ;;
    usage|stats|--usage|--stats)
        shift
        run_script "bin/usage-stats.sh" "$@"
        ;;
    aswap|antigravity-swap|--aswap)
        install_aswap
        ;;
    service|web|--service)
        shift
        run_script "bin/service.sh" "$@"
        ;;
    shortcuts|shortcut|--shortcuts)
        shift
        run_script "bin/setup-shortcuts.sh" "$@"
        ;;
    export|backup|--export)
        shift
        run_script "bin/export-config.sh" "$@"
        ;;
    restore|--restore)
        shift
        run_script "bin/restore-config.sh" "$@"
        ;;
    uninstall|--uninstall)
        shift
        run_script "bin/uninstall.sh" "$@"
        ;;
    *)
        show_menu
        ;;
esac
