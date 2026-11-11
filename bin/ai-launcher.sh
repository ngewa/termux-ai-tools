#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# AI Quick Launcher & Dispatcher for Termux
# Command: ai [command] [args...]
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TOOLS_DIR="${HOME:-/data/data/com.termux/files/home}/termux-ai-tools"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

# Handle CLI arguments directly
case "$1" in
    oc|opencode|1)
        shift
        if [ -x "$PREFIX/bin/opencode" ]; then
            exec "$PREFIX/bin/opencode" "$@"
        else
            echo -e "${RED}[ERROR]${RESET} OpenCode v1 belum terpasang. Jalankan: ai-tools install opencode"
            exit 1
        fi
        ;;
    oc2|opencode-v2|2)
        shift
        if [ -x "$PREFIX/bin/opencode-v2" ]; then
            exec "$PREFIX/bin/opencode-v2" "$@"
        else
            echo -e "${RED}[ERROR]${RESET} OpenCode v2 belum terpasang. Jalankan: ai-tools install opencode-v2"
            exit 1
        fi
        ;;
    agy|antigravity|3)
        shift
        if [ -x "$PREFIX/bin/agy" ]; then
            exec "$PREFIX/bin/agy" "$@"
        else
            echo -e "${RED}[ERROR]${RESET} Antigravity CLI belum terpasang. Jalankan: ai-tools install agy"
            exit 1
        fi
        ;;
    web)
        shift
        if [ -f "$TOOLS_DIR/service.sh" ]; then
            exec bash "$TOOLS_DIR/service.sh" start v2 "$@"
        else
            if [ -x "$PREFIX/bin/opencode-v2" ]; then
                exec "$PREFIX/bin/opencode-v2" serve "$@"
            else
                exec "$PREFIX/bin/opencode" web "$@"
            fi
        fi
        ;;
    service)
        shift
        if [ -f "$TOOLS_DIR/service.sh" ]; then
            exec bash "$TOOLS_DIR/service.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/service.sh | bash -s -- "$@"
        fi
        ;;

    usage|stats)
        shift
        if [ -f "$TOOLS_DIR/bin/usage-stats.sh" ]; then
            exec bash "$TOOLS_DIR/bin/usage-stats.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/bin/usage-stats.sh | bash -s -- "$@"
        fi
        ;;

    doc|doctor)
        shift
        if [ -f "$TOOLS_DIR/doctor.sh" ]; then
            exec bash "$TOOLS_DIR/doctor.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- doctor "$@"
        fi
        ;;
    up|update)
        shift
        if [ -f "$TOOLS_DIR/update.sh" ]; then
            exec bash "$TOOLS_DIR/update.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/update.sh | bash -s -- "$@"
        fi
        ;;
    backup|export)
        shift
        if [ -f "$TOOLS_DIR/backup.sh" ]; then
            exec bash "$TOOLS_DIR/backup.sh" export "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- export "$@"
        fi
        ;;
    restore)
        shift
        if [ -f "$TOOLS_DIR/backup.sh" ]; then
            exec bash "$TOOLS_DIR/backup.sh" restore "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- restore "$@"
        fi
        ;;
    cfg|config)
        shift
        if [ -f "$TOOLS_DIR/config.sh" ]; then
            exec bash "$TOOLS_DIR/config.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/config.sh | bash -s -- "$@"
        fi
        ;;
    sess|session)
        shift
        if [ -f "$TOOLS_DIR/session.sh" ]; then
            exec bash "$TOOLS_DIR/session.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/session.sh | bash -s -- "$@"
        fi
        ;;
    plugin|mcp)
        shift
        if [ -f "$TOOLS_DIR/plugin.sh" ]; then
            exec bash "$TOOLS_DIR/plugin.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/plugin.sh | bash -s -- "$@"
        fi
        ;;
    mem|memory)
        shift
        if [ -f "$TOOLS_DIR/memory.sh" ]; then
            exec bash "$TOOLS_DIR/memory.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/memory.sh | bash -s -- "$@"
        fi
        ;;
    skill|skills)
        shift
        if [ -f "$TOOLS_DIR/skill.sh" ]; then
            exec bash "$TOOLS_DIR/skill.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/skill.sh | bash -s -- "$@"
        fi
        ;;
    agent|agents)
        shift
        if [ -f "$TOOLS_DIR/agent.sh" ]; then
            exec bash "$TOOLS_DIR/agent.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/agent.sh | bash -s -- "$@"
        fi
        ;;
    acc|account|auth)
        shift
        if [ -f "$TOOLS_DIR/account.sh" ]; then
            exec bash "$TOOLS_DIR/account.sh" "$@"
        elif [ -f "$TOOLS_DIR/bin/account-manager.sh" ]; then
            exec bash "$TOOLS_DIR/bin/account-manager.sh" "$@"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/account.sh | bash -s -- "$@"
        fi
        ;;
    aswap|swap)
        shift
        if command -v aswap >/dev/null 2>&1; then
            exec aswap "$@"
        else
            echo -e "${YELLOW}[WARN]${RESET} aswap belum terpasang. Menginstal via pip..."
            pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            exec aswap "$@"
        fi
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - Quick Launcher Usage:${RESET}"
        echo -e "  ${GREEN}ai${RESET}                       Buka menu interaktif pemilih AI"
        echo -e "  ${GREEN}ai oc [args...]${RESET}          Jalankan OpenCode v1 langsung"
        echo -e "  ${GREEN}ai oc2 [args...]${RESET}         Jalankan OpenCode v2 langsung"
        echo -e "  ${GREEN}ai agy [args...]${RESET}         Jalankan Antigravity CLI langsung"
        echo -e "  ${GREEN}ai web${RESET}                   Buka mode Web UI OpenCode & Browser"
        echo -e "  ${CYAN}ai skill [args...]${RESET}       Kelola AI Agent Skills (Prompt Master, Antislop, UI)"
        echo -e "  ${CYAN}ai agent [args...]${RESET}       Kelola AI Personas & Subagents (Roblox, Toolkit)"
        echo -e "  ${CYAN}ai memory [args...]${RESET}      Kelola Knowledge Memory & AI Brain persisten (FTS5)"
        echo -e "  ${CYAN}ai plugin [args...]${RESET}      Pasang MCP servers & OpenCode plugins"
        echo -e "  ${CYAN}ai account [args...]${RESET}     Multi-account registry, kuota & auto-rotasi"
        echo -e "  ${CYAN}ai aswap [args...]${RESET}       Antigravity CLI (agy) account switcher & quota live"
        echo -e "  ${CYAN}ai stats [args...]${RESET}       Statistik token, request & histori pemakaian"
        echo -e "  ${CYAN}ai config [args...]${RESET}      Wizard pengaturan API key & default model"
        echo -e "  ${CYAN}ai session [args...]${RESET}     Kelola sesi riwayat, ekspor & vacuum storage"
        echo -e "  ${CYAN}ai doctor${RESET}                Jalankan pemeriksaan kesehatan sistem"
        echo -e "  ${CYAN}ai update${RESET}                Cek & update versi terbaru dari GitHub"
        echo -e "  ${CYAN}ai backup${RESET}                Export / backup pengaturan & token"
        echo -e "  ${CYAN}ai restore${RESET}               Restore pengaturan dari file backup"
        exit 0
        ;;
esac

# Interactive Menu if run without arguments
clear 2>/dev/null || true
echo -e "${BOLD}${CYAN}╭────────────────────────────────────────────────────────╮${RESET}"
echo -e "${BOLD}${CYAN}│        ⚡ Termux AI Tools Quick Launcher               │${RESET}"
echo -e "${BOLD}${CYAN}│          ${DIM}Unified AI Ecosystem for Termux${RESET}${BOLD}${CYAN}               │${RESET}"
echo -e "${BOLD}${CYAN}╰────────────────────────────────────────────────────────╯${RESET}"
echo ""

# Get versions if installed
V1_VER="${DIM}[Belum terpasang]${RESET}"
if [ -x "$PREFIX/bin/opencode" ]; then
    v="$("$PREFIX/bin/opencode" --version 2>/dev/null | head -n1 | sed -e 's/^opencode //' -e 's/^[vV]//')"
    [ -n "$v" ] && V1_VER="${CYAN}(v${v})${RESET}" || V1_VER="${CYAN}(OK)${RESET}"
fi

V2_VER="${DIM}[Belum terpasang]${RESET}"
if [ -x "$PREFIX/bin/opencode-v2" ]; then
    v="$("$PREFIX/bin/opencode-v2" --version 2>/dev/null | head -n1 | sed -e 's/^opencode //' -e 's/^[vV]//')"
    [ -n "$v" ] && V2_VER="${CYAN}(v${v})${RESET}" || V2_VER="${CYAN}(OK)${RESET}"
fi

AGY_VER="${DIM}[Belum terpasang]${RESET}"
if [ -x "$PREFIX/bin/agy" ]; then
    v="$("$PREFIX/bin/agy" --version 2>/dev/null | head -n1 | sed -e 's/^antigravity //' -e 's/^[vV]//')"
    [ -n "$v" ] && AGY_VER="${CYAN}(v${v})${RESET}" || AGY_VER="${CYAN}(OK)${RESET}"
fi

echo -e " ${BOLD}${YELLOW}▸ AI Coding Assistants${RESET}"
printf "   ${GREEN}%2s)${RESET} ${BOLD}%-23s${RESET} %b\n" "1" "OpenCode v1" "${V1_VER}"
printf "   ${GREEN}%2s)${RESET} ${BOLD}%-23s${RESET} %b\n" "2" "OpenCode v2" "${V2_VER}"
printf "   ${GREEN}%2s)${RESET} ${BOLD}%-23s${RESET} %b\n" "3" "Antigravity CLI" "${AGY_VER}"
printf "   ${GREEN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "4" "OpenCode Web UI" "(Server Web & Browser)"
echo ""

echo -e " ${BOLD}${YELLOW}▸ AI Brain & Agent Extensions${RESET}"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "5" "AI Agent Skills" "(Prompt Master, Antislop, UI/UX)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "6" "Subagents & Personas" "(Roblox, Toolkit, Reverser)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "7" "Knowledge Memory" "(AI Brain terverifikasi & FTS5)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "8" "Plugin & MCP Tools" "(Termux device, bridge & API)"
echo ""

echo -e " ${BOLD}${YELLOW}▸ Akun, Kuota & Statistik${RESET}"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "9" "Multi-Account & Pool" "(Akun personal/kerja, rotasi & aswap)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "10" "Usage Statistics" "(Token, request & pemakaian harian)"
echo ""

echo -e " ${BOLD}${YELLOW}▸ Konfigurasi & Pemeliharaan${RESET}"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "11" "Konfigurasi AI & Key" "(Setup API key & default model)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "12" "Manajemen Sesi & DB" "(Cari riwayat, ekspor & vacuum)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "13" "Diagnostik Sistem" "(Doctor & audit kesehatan sistem)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "14" "Pengecekan Update" "(Cek rilis upstream & git sync)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "15" "Backup Pengaturan" "(Export settings & token arsip)"
printf "   ${CYAN}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "16" "Restore Pengaturan" "(Restore data dari file backup)"
echo ""

printf "   ${YELLOW}%2s)${RESET} ${BOLD}%-23s${RESET} ${DIM}%s${RESET}\n" "0" "Keluar" "(atau ketik 17 / q / exit)"
echo ""

read -r -p "Masukkan pilihan [0-16]: " choice

case "$choice" in
    1|oc|opencode)
        if [ -x "$PREFIX/bin/opencode" ]; then
            exec "$PREFIX/bin/opencode"
        else
            echo -e "${RED}[ERROR]${RESET} OpenCode v1 belum terpasang!"
        fi
        ;;
    2|oc2|opencode-v2)
        if [ -x "$PREFIX/bin/opencode-v2" ]; then
            exec "$PREFIX/bin/opencode-v2"
        else
            echo -e "${RED}[ERROR]${RESET} OpenCode v2 belum terpasang!"
        fi
        ;;
    3|agy|antigravity)
        if [ -x "$PREFIX/bin/agy" ]; then
            exec "$PREFIX/bin/agy"
        else
            echo -e "${RED}[ERROR]${RESET} Antigravity CLI belum terpasang!"
        fi
        ;;
    4|web|ui)
        if [ -f "$TOOLS_DIR/service.sh" ]; then
            exec bash "$TOOLS_DIR/service.sh"
        elif [ -x "$PREFIX/bin/opencode-v2" ]; then
            exec "$PREFIX/bin/opencode-v2" serve
        elif [ -x "$PREFIX/bin/opencode" ]; then
            exec "$PREFIX/bin/opencode" web
        fi
        ;;
    5|skill|skills|aiskill)
        if [ -f "$TOOLS_DIR/skill.sh" ]; then
            exec bash "$TOOLS_DIR/skill.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/skill.sh | bash
        fi
        ;;
    6|agent|agents|aiagent)
        if [ -f "$TOOLS_DIR/agent.sh" ]; then
            exec bash "$TOOLS_DIR/agent.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/agent.sh | bash
        fi
        ;;
    7|mem|memory|aimem|brain)
        if [ -f "$TOOLS_DIR/memory.sh" ]; then
            exec bash "$TOOLS_DIR/memory.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/memory.sh | bash
        fi
        ;;
    8|plugin|plugins|mcp|aiplugin)
        if [ -f "$TOOLS_DIR/plugin.sh" ]; then
            exec bash "$TOOLS_DIR/plugin.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/plugin.sh | bash
        fi
        ;;
    9|acc|account|auth|aiaccount)
        if [ -f "$TOOLS_DIR/account.sh" ]; then
            exec bash "$TOOLS_DIR/account.sh"
        elif [ -f "$TOOLS_DIR/bin/account-manager.sh" ]; then
            exec bash "$TOOLS_DIR/bin/account-manager.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/account.sh | bash
        fi
        ;;
    10|usage|stats|stat)
        if [ -f "$TOOLS_DIR/bin/usage-stats.sh" ]; then
            exec bash "$TOOLS_DIR/bin/usage-stats.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/bin/usage-stats.sh | bash
        fi
        ;;
    11|cfg|config|aiconfig)
        if [ -f "$TOOLS_DIR/config.sh" ]; then
            exec bash "$TOOLS_DIR/config.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/config.sh | bash
        fi
        ;;
    12|sess|session|aisession)
        if [ -f "$TOOLS_DIR/session.sh" ]; then
            exec bash "$TOOLS_DIR/session.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/session.sh | bash
        fi
        ;;
    13|doc|doctor|aidoc)
        if [ -f "$TOOLS_DIR/doctor.sh" ]; then
            exec bash "$TOOLS_DIR/doctor.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- doctor
        fi
        ;;
    14|up|update|aiup)
        if [ -f "$TOOLS_DIR/update.sh" ]; then
            exec bash "$TOOLS_DIR/update.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/update.sh | bash
        fi
        ;;
    15|backup|export)
        if [ -f "$TOOLS_DIR/backup.sh" ]; then
            exec bash "$TOOLS_DIR/backup.sh" export
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- export
        fi
        ;;
    16|restore|import)
        if [ -f "$TOOLS_DIR/backup.sh" ]; then
            exec bash "$TOOLS_DIR/backup.sh" restore
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- restore
        fi
        ;;
    aswap|swap)
        if command -v aswap >/dev/null 2>&1; then
            exec aswap
        else
            echo -e "${YELLOW}[WARN]${RESET} aswap belum terpasang. Menginstal via pip..."
            pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            exec aswap
        fi
        ;;
    0|17|q|Q|quit|exit|x|"")
        echo -e "${CYAN}Sampai jumpa!${RESET}"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${RESET} Pilihan '$choice' tidak valid."
        exit 1
        ;;
esac
