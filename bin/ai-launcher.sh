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
    help|--help|-h)
        echo -e "${BOLD}${CYAN}AI Quick Launcher Usage:${RESET}"
        echo "  ai                  Buka menu interaktif pemilih AI"
        echo "  ai oc [args...]     Jalankan OpenCode v1 langsung"
        echo "  ai oc2 [args...]    Jalankan OpenCode v2 langsung"
        echo "  ai agy [args...]    Jalankan Antigravity CLI langsung"
        echo "  ai web              Buka mode Web UI OpenCode"
        echo "  ai session [args...]Kelola sesi, cari riwayat & vacuum storage"
        echo "  ai memory [args...] Kelola Knowledge Memory & AI Brain persisten"
        echo "  ai plugin [args...] Pasang MCP servers & OpenCode plugins"
        echo "  ai skill [args...]  Kelola AI Agent Skills (Prompt Master, Antislop, UI/UX)"
        echo "  ai agent [args...]  Kelola AI Subagents & Personas (Roblox, Toolkit, Reverser)"
        echo "  ai config [args...] Wizard pengaturan API key & default model"
        echo "  ai doctor           Jalankan pemeriksaan kesehatan sistem"
        echo "  ai update           Cek & update versi terbaru dari GitHub"
        echo "  ai backup           Export / backup pengaturan & token"
        echo "  ai restore          Restore pengaturan dari file backup"
        exit 0
        ;;
esac

# Interactive Menu if run without arguments
clear 2>/dev/null || true
echo -e "${BOLD}${CYAN}=================================================="
echo "        ⚡ Termux AI Tools Quick Launcher        "
echo -e "==================================================${RESET}"

# Get versions if installed
V1_VER="[Tidak terpasang]"
[ -x "$PREFIX/bin/opencode" ] && V1_VER="($("$PREFIX/bin/opencode" --version 2>/dev/null || echo 'OK'))"

V2_VER="[Tidak terpasang]"
[ -x "$PREFIX/bin/opencode-v2" ] && V2_VER="($("$PREFIX/bin/opencode-v2" --version 2>/dev/null || echo 'OK'))"

AGY_VER="[Tidak terpasang]"
[ -x "$PREFIX/bin/agy" ] && AGY_VER="($("$PREFIX/bin/agy" --version 2>/dev/null || echo 'OK'))"

echo -e "\n${BOLD}Pilih AI coding assistant:${RESET}"
echo -e "  ${GREEN}1)${RESET} OpenCode v1          ${CYAN}${V1_VER}${RESET}"
echo -e "  ${GREEN}2)${RESET} OpenCode v2          ${CYAN}${V2_VER}${RESET}"
echo -e "  ${GREEN}3)${RESET} Antigravity CLI      ${CYAN}${AGY_VER}${RESET}"
echo -e "  ${GREEN}4)${RESET} OpenCode Web UI      (Buka server web)"
echo -e "  ${CYAN}5)${RESET} Pengecekan Update    (Cek rilis baru upstream)"
echo -e "  ${CYAN}6)${RESET} Diagnostik Sistem    (Doctor & Health check)"
echo -e "  ${CYAN}7)${RESET} Manajemen Sesi & DB  (Cari sesi, ekspor & vacuum storage)"
echo -e "  ${CYAN}8)${RESET} Plugin & MCP Tools   (Termux device, web fetch, db)"
echo -e "  ${CYAN}9)${RESET} Konfigurasi AI & Key (Setup API key & model)"
echo -e "  ${CYAN}10)${RESET} Backup Pengaturan   (Export settings & tokens)"
echo -e "  ${CYAN}11)${RESET} Restore Pengaturan  (Restore dari arsip)"
echo -e "  ${CYAN}12)${RESET} Knowledge Memory & AI Brain (Solusi terverifikasi & search FTS5)"
echo -e "  ${CYAN}13)${RESET} AI Agent Skills     (Prompt Master, Antislop, UI/UX Design)"
echo -e "  ${CYAN}14)${RESET} AI Subagents & Personas (Roblox, Toolkit, Reverser)"
echo -e "  ${YELLOW}15)${RESET} Keluar"
echo ""

read -r -p "Masukkan pilihan [1-15]: " choice

case "$choice" in
    1)
        if [ -x "$PREFIX/bin/opencode" ]; then
            exec "$PREFIX/bin/opencode"
        else
            echo -e "${RED}OpenCode v1 belum terpasang!${RESET}"
        fi
        ;;
    2)
        if [ -x "$PREFIX/bin/opencode-v2" ]; then
            exec "$PREFIX/bin/opencode-v2"
        else
            echo -e "${RED}OpenCode v2 belum terpasang!${RESET}"
        fi
        ;;
    3)
        if [ -x "$PREFIX/bin/agy" ]; then
            exec "$PREFIX/bin/agy"
        else
            echo -e "${RED}Antigravity CLI belum terpasang!${RESET}"
        fi
        ;;
    4)
        if [ -f "$TOOLS_DIR/service.sh" ]; then
            exec bash "$TOOLS_DIR/service.sh"
        elif [ -x "$PREFIX/bin/opencode-v2" ]; then
            exec "$PREFIX/bin/opencode-v2" serve
        elif [ -x "$PREFIX/bin/opencode" ]; then
            exec "$PREFIX/bin/opencode" web
        fi
        ;;

    5)
        if [ -f "$TOOLS_DIR/update.sh" ]; then
            exec bash "$TOOLS_DIR/update.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/update.sh | bash
        fi
        ;;
    6)
        if [ -f "$TOOLS_DIR/doctor.sh" ]; then
            exec bash "$TOOLS_DIR/doctor.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- doctor
        fi
        ;;
    7)
        if [ -f "$TOOLS_DIR/session.sh" ]; then
            exec bash "$TOOLS_DIR/session.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/session.sh | bash
        fi
        ;;
    8)
        if [ -f "$TOOLS_DIR/plugin.sh" ]; then
            exec bash "$TOOLS_DIR/plugin.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/plugin.sh | bash
        fi
        ;;
    9)
        if [ -f "$TOOLS_DIR/config.sh" ]; then
            exec bash "$TOOLS_DIR/config.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/config.sh | bash
        fi
        ;;
    10)
        if [ -f "$TOOLS_DIR/backup.sh" ]; then
            exec bash "$TOOLS_DIR/backup.sh" export
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- export
        fi
        ;;
    11)
        if [ -f "$TOOLS_DIR/backup.sh" ]; then
            exec bash "$TOOLS_DIR/backup.sh" restore
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- restore
        fi
        ;;
    12)
        if [ -f "$TOOLS_DIR/memory.sh" ]; then
            exec bash "$TOOLS_DIR/memory.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/memory.sh | bash
        fi
        ;;
    13)
        if [ -f "$TOOLS_DIR/skill.sh" ]; then
            exec bash "$TOOLS_DIR/skill.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/skill.sh | bash
        fi
        ;;
    14)
        if [ -f "$TOOLS_DIR/agent.sh" ]; then
            exec bash "$TOOLS_DIR/agent.sh"
        else
            exec curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/agent.sh | bash
        fi
        ;;
    *)
        echo "Selesai."
        exit 0
        ;;
esac
