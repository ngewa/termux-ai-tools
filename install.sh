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
echo "      OpenCode & Antigravity CLI (agy)           "
echo "=================================================="
echo -e "${RESET}"

show_menu() {
    echo -e "${BOLD}Pilih opsi instalasi/update:${RESET}"
    echo -e "  ${GREEN}1)${RESET} Install / Update OpenCode (Latest upstream v1.19.4)"
    echo -e "  ${GREEN}2)${RESET} Install / Update Antigravity CLI (agy v1.3.5 stabil)"
    echo -e "  ${GREEN}3)${RESET} Install / Update Keduanya (OpenCode + AGY)"
    echo -e "  ${GREEN}4)${RESET} Cek Status & Versi Terpasang"
    echo -e "  ${GREEN}5)${RESET} Keluar"
    echo ""
    read -r -p "Pilihan Anda [1-5]: " opt
    case "$opt" in
        1)
            local s
            s=$(get_script "bin/install-opencode.sh")
            bash "$s"
            ;;
        2)
            local s
            s=$(get_script "bin/install-agy.sh")
            bash "$s"
            ;;
        3)
            local s1 s2
            s1=$(get_script "bin/install-opencode.sh")
            s2=$(get_script "bin/install-agy.sh")
            bash "$s1"
            bash "$s2"
            ;;
        4)
            local s
            s=$(get_script "update.sh")
            bash "$s"
            ;;
        5)
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
    opencode|--opencode)
        s=$(get_script "bin/install-opencode.sh")
        bash "$s" "$2"
        ;;
    agy|--agy)
        s=$(get_script "bin/install-agy.sh")
        bash "$s" "$2"
        ;;
    all|--all)
        s1=$(get_script "bin/install-opencode.sh")
        s2=$(get_script "bin/install-agy.sh")
        bash "$s1"
        bash "$s2"
        ;;
    check|update|--check)
        s=$(get_script "update.sh")
        bash "$s"
        ;;
    *)
        show_menu
        ;;
esac
