#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Setup Shortcuts, Shell Aliases, and Termux:Widget Launcher for AI Tools
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SHORTCUTS_DIR="$HOME_DIR/.shortcuts"

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

REMOVE_MODE=false
for arg in "$@"; do
    if [ "$arg" = "--remove" ] || [ "$arg" = "--uninstall" ] || [ "$arg" = "-r" ]; then
        REMOVE_MODE=true
    fi
done

echo -e "\n${BOLD}${CYAN}=== Termux AI Tools - Quick Launcher & Shortcuts Setup ===${RESET}\n"

# ------------------------------------------------------------------------------
# 1. Install or Remove Global 'ai' & Helper Commands
# ------------------------------------------------------------------------------
AI_BIN="$PREFIX/bin/ai"
if [ "$REMOVE_MODE" = "true" ]; then
    log_info "Menghapus perintah global 'ai' dan symlink..."
    rm -f "$AI_BIN" "$PREFIX/bin/doctor.sh" "$PREFIX/bin/update.sh" "$PREFIX/bin/backup.sh" "$PREFIX/bin/service.sh" "$PREFIX/bin/config.sh" "$PREFIX/bin/aiconfig" "$PREFIX/bin/session.sh" "$PREFIX/bin/aisession" "$PREFIX/bin/plugin.sh" "$PREFIX/bin/aiplugin" "$PREFIX/bin/memory.sh" "$PREFIX/bin/aimem" "$PREFIX/bin/skill.sh" "$PREFIX/bin/aiskill"
    log_ok "Perintah global berhasil dibersihkan."
else
    log_info "Memasang perintah global 'ai' ke $AI_BIN..."
    if [ -f "$SCRIPT_DIR/ai-launcher.sh" ]; then
        cp "$SCRIPT_DIR/ai-launcher.sh" "$AI_BIN"
    elif [ -f "$REPO_DIR/bin/ai-launcher.sh" ]; then
        cp "$REPO_DIR/bin/ai-launcher.sh" "$AI_BIN"
    else
        curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/bin/ai-launcher.sh -o "$AI_BIN"
    fi
    chmod 755 "$AI_BIN"

    # Create global symlinks for doctor, update, backup, service, config, session, plugin, memory, and skill if repo exists locally
    if [ -d "$REPO_DIR" ]; then
        ln -sf "$REPO_DIR/doctor.sh" "$PREFIX/bin/doctor.sh"
        ln -sf "$REPO_DIR/update.sh" "$PREFIX/bin/update.sh"
        ln -sf "$REPO_DIR/backup.sh" "$PREFIX/bin/backup.sh"
        ln -sf "$REPO_DIR/service.sh" "$PREFIX/bin/service.sh"
        ln -sf "$REPO_DIR/config.sh" "$PREFIX/bin/config.sh"
        ln -sf "$REPO_DIR/config.sh" "$PREFIX/bin/aiconfig"
        ln -sf "$REPO_DIR/session.sh" "$PREFIX/bin/session.sh"
        ln -sf "$REPO_DIR/session.sh" "$PREFIX/bin/aisession"
        ln -sf "$REPO_DIR/plugin.sh" "$PREFIX/bin/plugin.sh"
        ln -sf "$REPO_DIR/plugin.sh" "$PREFIX/bin/aiplugin"
        ln -sf "$REPO_DIR/memory.sh" "$PREFIX/bin/memory.sh"
        ln -sf "$REPO_DIR/memory.sh" "$PREFIX/bin/aimem"
        ln -sf "$REPO_DIR/skill.sh" "$PREFIX/bin/skill.sh"
        ln -sf "$REPO_DIR/skill.sh" "$PREFIX/bin/aiskill"
    fi
    log_ok "Perintah 'ai', 'skill.sh', 'aiskill', 'plugin.sh', 'session.sh', 'memory.sh', 'aimem', 'config.sh', 'doctor.sh', 'service.sh' kini dapat dijalankan dari terminal mana saja!"

fi


# ------------------------------------------------------------------------------
# 2. Setup / Remove Shell Aliases (.bashrc & .zshrc)
# ------------------------------------------------------------------------------
ALIAS_START="# >>> termux-ai-tools aliases >>>"
ALIAS_END="# <<< termux-ai-tools aliases <<<"

manage_shell_rc() {
    local rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        touch "$rc_file"
    fi

    # Remove existing alias block first
    sed -i "/$ALIAS_START/,/$ALIAS_END/d" "$rc_file" 2>/dev/null || true

    if [ "$REMOVE_MODE" != "true" ]; then
        cat >> "$rc_file" << EOF

$ALIAS_START
alias oc="opencode"
alias oc2="opencode-v2"
alias aidoc="doctor.sh"
alias aiup="update.sh"
alias aicfg="config.sh"
alias aisess="session.sh"
alias aiplug="plugin.sh"
alias aimem="memory.sh"
alias aiskill="skill.sh"
$ALIAS_END
EOF
        log_ok "Alias ditambahkan ke $(basename "$rc_file") (oc, oc2, aidoc, aiup, aicfg, aisess, aiplug, aimem, aiskill)"
    fi
}

log_info "Mengonfigurasi shell aliases..."
[ -f "$HOME_DIR/.bashrc" ] || touch "$HOME_DIR/.bashrc"
manage_shell_rc "$HOME_DIR/.bashrc"

if [ -f "$HOME_DIR/.zshrc" ]; then
    manage_shell_rc "$HOME_DIR/.zshrc"
fi

# ------------------------------------------------------------------------------
# 3. Setup / Remove Termux:Widget Shortcuts (~/.shortcuts/)
# ------------------------------------------------------------------------------
if [ "$REMOVE_MODE" = "true" ]; then
    log_info "Menghapus shortcut Termux:Widget..."
    rm -f "$SHORTCUTS_DIR/OpenCode.sh" \
          "$SHORTCUTS_DIR/OpenCode-v2.sh" \
          "$SHORTCUTS_DIR/Antigravity-CLI.sh" \
          "$SHORTCUTS_DIR/AI-Menu.sh" \
          "$SHORTCUTS_DIR/AI-Web.sh" \
          "$SHORTCUTS_DIR/AI-Config.sh" \
          "$SHORTCUTS_DIR/AI-Session.sh" \
          "$SHORTCUTS_DIR/AI-Plugin.sh" \
          "$SHORTCUTS_DIR/AI-Skill.sh" \
          "$SHORTCUTS_DIR/AI-Memory.sh" \
          "$SHORTCUTS_DIR/AI-Doctor.sh"
    log_ok "Shortcut Termux:Widget berhasil dibersihkan."
else
    log_info "Menyiapkan direktori Termux:Widget di $SHORTCUTS_DIR..."
    mkdir -p "$SHORTCUTS_DIR" "$SHORTCUTS_DIR/tasks"

    # 1. AI Menu Launcher
    cat > "$SHORTCUTS_DIR/AI-Menu.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec ai
EOF

    # 2. OpenCode v1 Shortcut
    cat > "$SHORTCUTS_DIR/OpenCode.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec opencode "$@"
EOF

    # 3. OpenCode v2 Shortcut
    cat > "$SHORTCUTS_DIR/OpenCode-v2.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec opencode-v2 "$@"
EOF

    # 4. Antigravity CLI Shortcut
    cat > "$SHORTCUTS_DIR/Antigravity-CLI.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec agy "$@"
EOF

    # 5. AI Doctor Shortcut
    cat > "$SHORTCUTS_DIR/AI-Doctor.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
doctor.sh
echo ""
read -r -p "Tekan ENTER untuk keluar..." _
EOF

    # 6. AI Web Server & Browser Shortcut
    cat > "$SHORTCUTS_DIR/AI-Web.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
service.sh start v2
EOF

    # 7. AI Config Wizard Shortcut
    cat > "$SHORTCUTS_DIR/AI-Config.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
config.sh
EOF

    # 8. AI Session & Storage Manager Shortcut
    cat > "$SHORTCUTS_DIR/AI-Session.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
session.sh
EOF

    # 9. AI Plugin & MCP Installer Shortcut
    cat > "$SHORTCUTS_DIR/AI-Plugin.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
plugin.sh
EOF

    # 10. AI Agent Skill Manager Shortcut
    cat > "$SHORTCUTS_DIR/AI-Skill.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
skill.sh
EOF

    # 11. AI Knowledge Memory / Brain Shortcut
    cat > "$SHORTCUTS_DIR/AI-Memory.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
memory.sh
EOF

    chmod +x "$SHORTCUTS_DIR"/*.sh
    log_ok "Shortcut Termux:Widget berhasil dibuat:"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Menu.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Web.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Config.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Session.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Skill.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Memory.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Plugin.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/OpenCode.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/OpenCode-v2.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/Antigravity-CLI.sh${RESET}"
    echo -e "  • ${CYAN}$SHORTCUTS_DIR/AI-Doctor.sh${RESET}"

fi

# ------------------------------------------------------------------------------
# 4. Ringkasan
# ------------------------------------------------------------------------------
if [ "$REMOVE_MODE" = "true" ]; then
    echo -e "\n${BOLD}${GREEN}✅ Seluruh shortcut dan alias berhasil dibersihkan!${RESET}\n"
else
    echo -e "\n${BOLD}${GREEN}✅ Penyiapan Shortcut Selesai!${RESET}"
    echo -e "\n${BOLD}Cara Penggunaan Baru:${RESET}"
    echo -e "  1. Ketik ${CYAN}${BOLD}ai${RESET} di terminal mana saja untuk membuka menu peluncur interaktif."
    echo -e "  2. Gunakan alias cepat:"
    echo -e "     - ${CYAN}oc${RESET}   : Jalankan OpenCode v1"
    echo -e "     - ${CYAN}oc2${RESET}  : Jalankan OpenCode v2"
    echo -e "     - ${CYAN}aidoc${RESET}: Jalankan Health Doctor"
    echo -e "     - ${CYAN}aiup${RESET} : Cek & update versi rilis"
    echo -e "  3. Jika Anda menginstal aplikasi Android ${BOLD}Termux:Widget${RESET}, widget shortcut akan muncul di homescreen HP Anda!\n"
fi
