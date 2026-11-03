#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Cross-Platform AI Agent & Skill Synchronizer (Antigravity agy <-> OpenCode)
# ==============================================================================
set -e

HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
AGY_AGENTS="$HOME_DIR/.gemini/config/agents"
OC_AGENTS="$HOME_DIR/.config/opencode/agents"
UNIV_SKILLS="$HOME_DIR/.agents/skills"
AGY_SKILLS="$HOME_DIR/.gemini/skills"
OC_SKILLS="$HOME_DIR/.config/opencode/skills"

GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
BOLD="\033[1m"
RESET="\033[0m"

cmd="${1:-list}"
target="${2:-all}"

sync_agent() {
    local name="$1"
    local agy_path="$AGY_AGENTS/$name/agent.md"
    local oc_path="$OC_AGENTS/$name.md"

    mkdir -p "$AGY_AGENTS/$name" "$OC_AGENTS"

    if [ -f "$agy_path" ] && [ ! -f "$oc_path" ]; then
        cp "$agy_path" "$oc_path"
        echo -e "${GREEN}[OK]${RESET} Disinkronkan: AGY -> OpenCode ($name)"
    elif [ -f "$oc_path" ] && [ ! -f "$agy_path" ]; then
        cp "$oc_path" "$agy_path"
        echo -e "${GREEN}[OK]${RESET} Disinkronkan: OpenCode -> AGY ($name)"
    elif [ -f "$agy_path" ] && [ -f "$oc_path" ]; then
        # Check newer
        if [ "$agy_path" -nt "$oc_path" ]; then
            cp "$agy_path" "$oc_path"
            echo -e "${GREEN}[OK]${RESET} Diperbarui dari AGY -> OpenCode ($name)"
        elif [ "$oc_path" -nt "$agy_path" ]; then
            cp "$oc_path" "$agy_path"
            echo -e "${GREEN}[OK]${RESET} Diperbarui dari OpenCode -> AGY ($name)"
        else
            echo -e "${CYAN}[INFO]${RESET} Sudah sinkron ($name)"
        fi
    fi
}

case "$cmd" in
    sync)
        if [ "$target" = "all" ]; then
            echo -e "${BOLD}${CYAN}Menyinkronkan semua agent antara Antigravity dan OpenCode...${RESET}"
            # From AGY
            if [ -d "$AGY_AGENTS" ]; then
                for d in "$AGY_AGENTS"/*; do
                    [ -d "$d" ] || continue
                    name=$(basename "$d")
                    sync_agent "$name"
                done
            fi
            # From OC
            if [ -d "$OC_AGENTS" ]; then
                for f in "$OC_AGENTS"/*.md; do
                    [ -f "$f" ] || continue
                    name=$(basename "$f" .md)
                    sync_agent "$name"
                done
            fi
        else
            sync_agent "$target"
        fi
        ;;
    list|status)
        echo -e "${BOLD}${CYAN}====================================================${RESET}"
        echo -e "${BOLD}     Status AI Personas / Subagents Terpasang       ${RESET}"
        echo -e "${BOLD}${CYAN}====================================================${RESET}"
        printf "%-20s %-16s %-16s\n" "AGENT NAME" "ANTIGRAVITY" "OPENCODE"
        echo "----------------------------------------------------"

        declare -A all_names
        [ -d "$AGY_AGENTS" ] && for d in "$AGY_AGENTS"/*; do [ -d "$d" ] && all_names["$(basename "$d")"]=1; done
        [ -d "$OC_AGENTS" ] && for f in "$OC_AGENTS"/*.md; do [ -f "$f" ] && all_names["$(basename "$f" .md)"]=1; done

        for n in "${!all_names[@]}"; do
            agy_st="\033[31m[ TIDAK ]\033[0m"
            oc_st="\033[31m[ TIDAK ]\033[0m"
            [ -f "$AGY_AGENTS/$n/agent.md" ] && agy_st="\033[32m[ AKTIF ]\033[0m"
            [ -f "$OC_AGENTS/$n.md" ] && oc_st="\033[32m[ AKTIF ]\033[0m"
            printf "%-20s %b        %b\n" "$n" "$agy_st" "$oc_st"
        done
        ;;
    help|--help|-h)
        echo "Penggunaan: $0 [sync [agent_name|all] | list]"
        ;;
    *)
        echo "Perintah tidak dikenal: $cmd"
        exit 1
        ;;
esac
