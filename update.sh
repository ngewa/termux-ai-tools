#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# AI Tools Updater for Termux (OpenCode & Antigravity CLI)
# Real-time GitHub Upstream Releases Checker & Interactive Version Selector
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
CACHE_DIR="${HOME:-/data/data/com.termux/files/home}/.cache/termux-ai"
CACHE_TTL=300

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

mkdir -p "$CACHE_DIR"

# Helper to get cached data or fetch from GitHub
fetch_release_data() {
    local cache_file="$1"
    local url="$2"
    local force_refresh="$3"
    local now
    now=$(date +%s)
    local mtime=0
    if [ -f "$cache_file" ]; then
        mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
    fi

    if [ "$force_refresh" != "true" ] && [ -s "$cache_file" ] && [ $((now - mtime)) -lt $CACHE_TTL ]; then
        cat "$cache_file"
        return 0
    fi

    local data
    data=$(curl -sL --max-time 10 "$url" 2>/dev/null || echo "")
    if [ -n "$data" ] && echo "$data" | grep -q '"tag_name"'; then
        echo "$data" > "$cache_file"
        echo "$data"
    elif [ -s "$cache_file" ]; then
        cat "$cache_file"
    else
        echo ""
    fi
}

FORCE_REFRESH=false
if [ "${1:-}" = "--refresh" ] || [ "${2:-}" = "--refresh" ]; then
    FORCE_REFRESH=true
fi

echo -e "\n${BOLD}${CYAN}=== Memeriksa Update AI Tools di Termux (Live GitHub) ===${RESET}\n"

# 1. Fetch releases live from GitHub anomalyco/opencode
log_info "Mengambil data rilis resmi OpenCode dari GitHub (anomalyco/opencode)..."
OPENCODE_RELEASES_JSON=$(fetch_release_data "$CACHE_DIR/opencode_releases.json" "https://api.github.com/repos/anomalyco/opencode/releases?per_page=30" "$FORCE_REFRESH")

# Parse OpenCode v2 versions (clean, filtering out non-v2 like process-daemon)
OPENCODE2_LIST=()
if [ -n "$OPENCODE_RELEASES_JSON" ]; then
    mapfile -t OPENCODE2_LIST < <(echo "$OPENCODE_RELEASES_JSON" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | grep -E '^v?2\.[0-9]+' | head -n 6)
fi
if [ ${#OPENCODE2_LIST[@]} -eq 0 ]; then
    OPENCODE2_LIST=("v2.2.2" "v2.2.1" "v2.2.0")
fi
OPENCODE2_LATEST="${OPENCODE2_LIST[0]#v}"

# Parse OpenCode v1 versions (clean, filtering out non-v1 like process-daemon)
OPENCODE1_LIST=()
if [ -n "$OPENCODE_RELEASES_JSON" ]; then
    mapfile -t OPENCODE1_LIST < <(echo "$OPENCODE_RELEASES_JSON" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | grep -E '^v?1\.[0-9]+' | head -n 6)
fi
if [ ${#OPENCODE1_LIST[@]} -eq 0 ]; then
    OPENCODE1_LIST=("v1.19.5" "v1.19.4" "v1.19.3" "v1.19.2")
fi
OPENCODE_LATEST="${OPENCODE1_LIST[0]#v}"

# 2. Fetch releases live from GitHub google-antigravity/antigravity-cli
log_info "Mengambil data rilis resmi Antigravity CLI dari GitHub (google-antigravity/antigravity-cli)..."
AGY_RELEASES_JSON=$(fetch_release_data "$CACHE_DIR/agy_releases.json" "https://api.github.com/repos/google-antigravity/antigravity-cli/releases?per_page=30" "$FORCE_REFRESH")

AGY_LIST=()
if [ -n "$AGY_RELEASES_JSON" ]; then
    mapfile -t AGY_LIST < <(echo "$AGY_RELEASES_JSON" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | grep -E '^[v0-9]' | head -n 6)
fi
if [ ${#AGY_LIST[@]} -eq 0 ]; then
    AGY_LIST=("1.4.10" "1.4.9" "1.4.8")
fi
AGY_LATEST="${AGY_LIST[0]#v}"

# Ensure v1.3.5 is included in AGY list because it's the tested stable version for Termux ARM64 memory layout
HAS_135=false
for v in "${AGY_LIST[@]}"; do
    if [ "${v#v}" = "1.3.5" ]; then
        HAS_135=true
        break
    fi
done
if [ "$HAS_135" = false ]; then
    AGY_LIST+=("1.3.5")
fi

# 3. Detect installed versions
OPENCODE_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/opencode" ]; then
    RAW_V1=$("$PREFIX/bin/opencode" --version 2>/dev/null || echo "Unknown")
    OPENCODE_INSTALLED=$(echo "$RAW_V1" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

OPENCODE2_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/opencode-v2" ]; then
    RAW_V2=$("$PREFIX/bin/opencode-v2" --version 2>/dev/null || echo "Unknown")
    OPENCODE2_INSTALLED=$(echo "$RAW_V2" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

AGY_INSTALLED="Tidak terpasang"
if [ -f "$PREFIX/bin/agy" ]; then
    RAW_AGY=$("$PREFIX/bin/agy" --version 2>/dev/null || echo "Unknown")
    AGY_INSTALLED=$(echo "$RAW_AGY" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi

# 4. Display recent upstream release tags from GitHub (Neat, clean, categorized with [latest] markers)
echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${CYAN}  🌐 Rilis Terbaru di GitHub Upstream${RESET}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "\n${BOLD}${GREEN}📦 OpenCode v2${RESET} ${CYAN}(github.com/anomalyco/opencode)${RESET}:"
for i in "${!OPENCODE2_LIST[@]}"; do
    ver="${OPENCODE2_LIST[$i]}"
    extra=""
    if [ "$i" -eq 0 ]; then
        extra="  ${GREEN}${BOLD}[latest ⭐]${RESET}"
    fi
    if [ "${ver#v}" = "${OPENCODE2_INSTALLED#v}" ]; then
        extra="${extra}  ${CYAN}[aktif ✔️]${RESET}"
    fi
    echo -e "   • ${BOLD}${CYAN}${ver}${RESET}${extra}"
done

echo -e "\n${BOLD}${GREEN}📦 OpenCode v1${RESET} ${CYAN}(github.com/anomalyco/opencode)${RESET}:"
for i in "${!OPENCODE1_LIST[@]}"; do
    ver="${OPENCODE1_LIST[$i]}"
    extra=""
    if [ "$i" -eq 0 ]; then
        extra="  ${GREEN}${BOLD}[latest ⭐]${RESET}"
    fi
    if [ "${ver#v}" = "${OPENCODE_INSTALLED#v}" ]; then
        extra="${extra}  ${CYAN}[aktif ✔️]${RESET}"
    fi
    echo -e "   • ${BOLD}${CYAN}${ver}${RESET}${extra}"
done

echo -e "\n${BOLD}${GREEN}🚀 Antigravity CLI (AGY)${RESET} ${CYAN}(github.com/google-antigravity/antigravity-cli)${RESET}:"
for i in "${!AGY_LIST[@]}"; do
    ver="${AGY_LIST[$i]}"
    extra=""
    if [ "$i" -eq 0 ]; then
        extra="  ${GREEN}${BOLD}[latest ⭐]${RESET}"
    fi
    if [ "${ver#v}" = "1.3.5" ]; then
        extra="${extra}  ${YELLOW}[Stabil Android/Termux 🛡️]${RESET}"
    fi
    if [ "${ver#v}" = "${AGY_INSTALLED#v}" ]; then
        extra="${extra}  ${CYAN}[aktif ✔️]${RESET}"
    fi
    echo -e "   • ${BOLD}${CYAN}${ver}${RESET}${extra}"
done
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# 5. Status Summary Table
echo -e "\n${BOLD}Ringkasan Status di Termux Anda:${RESET}"
printf "%-18s | %-16s | %-16s | %-10s\n" "Software" "Terpasang" "Upstream (Last)" "Status"
echo "----------------------------------------------------------------------"

# OpenCode v1 status
if [ "$OPENCODE_INSTALLED" = "$OPENCODE_LATEST" ]; then
    OPENCODE_STATUS="${GREEN}Up-to-date${RESET}"
elif [ "$OPENCODE_INSTALLED" = "Tidak terpasang" ]; then
    OPENCODE_STATUS="${YELLOW}Belum ada${RESET}"
else
    OPENCODE_STATUS="${RED}Ada update! (${OPENCODE_LATEST})${RESET}"
fi
printf "%-18s | %-16s | %-16s | %-10b\n" "OpenCode v1" "$OPENCODE_INSTALLED" "$OPENCODE_LATEST" "$OPENCODE_STATUS"

# OpenCode v2 status
if [ "$OPENCODE2_INSTALLED" = "$OPENCODE2_LATEST" ]; then
    OPENCODE2_STATUS="${GREEN}Up-to-date${RESET}"
elif [ "$OPENCODE2_INSTALLED" = "Tidak terpasang" ]; then
    OPENCODE2_STATUS="${YELLOW}Belum ada${RESET}"
else
    OPENCODE2_STATUS="${RED}Ada update! (${OPENCODE2_LATEST})${RESET}"
fi
printf "%-18s | %-16s | %-16s | %-10b\n" "OpenCode v2" "$OPENCODE2_INSTALLED" "$OPENCODE2_LATEST" "$OPENCODE2_STATUS"

# AGY status
if [ "$AGY_INSTALLED" = "1.3.5" ]; then
    AGY_STATUS="${GREEN}Stabil (1.3.5)${RESET}"
elif [ "$AGY_INSTALLED" = "$AGY_LATEST" ]; then
    AGY_STATUS="${GREEN}Up-to-date (${AGY_LATEST})${RESET}"
elif [ "$AGY_INSTALLED" = "Tidak terpasang" ]; then
    AGY_STATUS="${YELLOW}Belum ada${RESET}"
else
    AGY_STATUS="${YELLOW}Versi: ${AGY_INSTALLED}${RESET}"
fi
printf "%-18s | %-16s | %-16s | %-10b\n" "Antigravity CLI" "$AGY_INSTALLED" "$AGY_LATEST" "$AGY_STATUS"
echo "----------------------------------------------------------------------"
echo -e "${YELLOW}Catatan AGY:${RESET} Versi 1.3.5 adalah build teruji paling stabil & kompatibel dengan patch memori Termux."
echo ""

# Helper function: Interactive version selection
SELECTED_VERSION=""
choose_version() {
    local tool_name="$1"
    local current_installed="$2"
    shift 2
    local versions=("$@")

    echo -e "\n${BOLD}${CYAN}=== Pilih / Ganti Versi ${tool_name} ===${RESET}"
    if [ -n "$current_installed" ] && [ "$current_installed" != "Tidak terpasang" ]; then
        echo -e "Versi terpasang saat ini: ${GREEN}${BOLD}${current_installed}${RESET}"
    fi

    local count=1
    for ver in "${versions[@]}"; do
        local badge=""
        local clean_v="${ver#v}"
        if [ $count -eq 1 ]; then
            badge="${GREEN}${BOLD}[latest ⭐]${RESET}"
        fi
        if [ "$clean_v" = "1.3.5" ]; then
            badge="${badge} ${YELLOW}[Stabil Termux 🛡️]${RESET}"
        fi
        if [ -n "$current_installed" ] && [ "$clean_v" = "${current_installed#v}" ]; then
            badge="${badge} ${CYAN}${BOLD}[aktif ✔️]${RESET}"
        fi
        printf "  ${BOLD}%2d)${RESET} %-12s %b\n" "$count" "$ver" "$badge"
        ((count++))
    done
    printf "  ${YELLOW}%2s)${RESET} Ketik versi kustom bebas (misal: 2.2.0)\n" "c"
    printf "  ${RED}%2s)${RESET} Batal / Kembali ke menu\n" "0"
    echo ""

    local choice
    read -r -p "Pilihan versi [1-$((count-1)), atau ketik versi langsung, default: 1 (${versions[0]})]: " choice
    choice="${choice:-1}"

    if [ "$choice" = "0" ] || [ "$choice" = "batal" ] || [ "$choice" = "q" ]; then
        echo -e "${YELLOW}Peralihan versi dibatalkan.${RESET}"
        SELECTED_VERSION=""
        return 1
    elif [ "$choice" = "c" ] || [ "$choice" = "C" ] || [ "$choice" = "m" ] || [ "$choice" = "M" ]; then
        read -r -p "Masukkan versi kustom target (contoh: 2.2.0): " manual_v
        SELECTED_VERSION="${manual_v#v}"
        if [ -z "$SELECTED_VERSION" ]; then
            echo -e "${RED}Versi tidak boleh kosong.${RESET}"
            return 1
        fi
        return 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$count" ]; then
        local idx=$((choice - 1))
        local picked="${versions[$idx]}"
        SELECTED_VERSION="${picked#v}"
        return 0
    elif [[ "$choice" =~ ^v?[0-9]+\.[0-9]+ ]]; then
        # User entered version directly like 2.2.1 or v1.19.4
        SELECTED_VERSION="${choice#v}"
        return 0
    else
        echo -e "${RED}Pilihan tidak valid!${RESET}"
        return 1
    fi
}

# Helper function: Standalone custom version switcher
custom_switcher() {
    echo -e "\n${BOLD}${CYAN}=== Ganti Versi Kustom Bebas (Upgrade / Downgrade) ===${RESET}"
    echo -e "Pilih AI tool yang ingin diubah versinya:"
    echo -e "  ${GREEN}1)${RESET} OpenCode v1          (Saat ini: ${OPENCODE_INSTALLED})"
    echo -e "  ${GREEN}2)${RESET} OpenCode v2          (Saat ini: ${OPENCODE2_INSTALLED})"
    echo -e "  ${GREEN}3)${RESET} Antigravity CLI (AGY)(Saat ini: ${AGY_INSTALLED})"
    echo -e "  ${RED}0)${RESET} Batal"
    echo ""
    read -r -p "Pilihan tool [1-3]: " t_choice

    case "$t_choice" in
        1)
            read -r -p "Masukkan versi OpenCode v1 target (contoh: 1.19.4): " custom_v
            custom_v="${custom_v#v}"
            if [ -n "$custom_v" ]; then
                log_info "Beralih ke OpenCode v1 versi $custom_v..."
                bash "$SCRIPT_DIR/bin/install-opencode.sh" "$custom_v" --force
            fi
            ;;
        2)
            read -r -p "Masukkan versi OpenCode v2 target (contoh: 2.2.1): " custom_v
            custom_v="${custom_v#v}"
            if [ -n "$custom_v" ]; then
                log_info "Beralih ke OpenCode v2 versi $custom_v..."
                bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$custom_v" --force
            fi
            ;;
        3)
            read -r -p "Masukkan versi Antigravity CLI target (contoh: 1.3.5 atau 1.4.10): " custom_v
            custom_v="${custom_v#v}"
            if [ -n "$custom_v" ]; then
                log_info "Beralih ke Antigravity CLI versi $custom_v..."
                bash "$SCRIPT_DIR/bin/install-agy.sh" "$custom_v" --force
            fi
            ;;
        *)
            echo -e "${YELLOW}Batal.${RESET}"
            ;;
    esac
}

# 6. Handle CLI arguments if provided
TARGET="${1:-}"
CUSTOM_VER="${2:-}"

if [ -n "$TARGET" ]; then
    case "$TARGET" in
        opencode|v1)
            if [ -n "$CUSTOM_VER" ] && [ "$CUSTOM_VER" != "--refresh" ]; then
                SELECTED_VERSION="${CUSTOM_VER#v}"
            elif [ -t 0 ]; then
                choose_version "OpenCode v1" "$OPENCODE_INSTALLED" "${OPENCODE1_LIST[@]}" || exit 0
            else
                SELECTED_VERSION="$OPENCODE_LATEST"
            fi
            log_info "Memulai update OpenCode v1 ke versi $SELECTED_VERSION..."
            bash "$SCRIPT_DIR/bin/install-opencode.sh" "$SELECTED_VERSION" --force
            exit 0
            ;;
        opencode-v2|v2)
            if [ -n "$CUSTOM_VER" ] && [ "$CUSTOM_VER" != "--refresh" ]; then
                SELECTED_VERSION="${CUSTOM_VER#v}"
            elif [ -t 0 ]; then
                choose_version "OpenCode v2" "$OPENCODE2_INSTALLED" "${OPENCODE2_LIST[@]}" || exit 0
            else
                SELECTED_VERSION="$OPENCODE2_LATEST"
            fi
            log_info "Memulai update OpenCode v2 ke versi $SELECTED_VERSION..."
            bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$SELECTED_VERSION" --force
            exit 0
            ;;
        agy)
            if [ -n "$CUSTOM_VER" ] && [ "$CUSTOM_VER" != "--refresh" ]; then
                SELECTED_VERSION="${CUSTOM_VER#v}"
            elif [ -t 0 ]; then
                choose_version "Antigravity CLI (AGY)" "$AGY_INSTALLED" "${AGY_LIST[@]}" || exit 0
            else
                SELECTED_VERSION="1.3.5"
            fi
            log_info "Memulai update / pasang Antigravity CLI ke versi $SELECTED_VERSION..."
            bash "$SCRIPT_DIR/bin/install-agy.sh" "$SELECTED_VERSION" --force
            exit 0
            ;;
        custom|switch)
            custom_switcher
            exit 0
            ;;
        all)
            log_info "Mengupdate semua tools ke versi rilis terbaru / stabil..."
            bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST" --force
            bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$OPENCODE2_LATEST" --force
            bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5" --force
            exit 0
            ;;
        --check|check)
            # Only status check was requested
            exit 0
            ;;
        --refresh)
            # Checked with force refresh and exit
            exit 0
            ;;
    esac
fi

# 7. Interactive menu if no arguments
echo -e "${BOLD}Pilihan tindakan:${RESET}"
echo -e "  ${GREEN}1)${RESET} OpenCode v1          (Pilih / Ganti versi)"
echo -e "  ${GREEN}2)${RESET} OpenCode v2          (Pilih / Ganti versi)"
echo -e "  ${GREEN}3)${RESET} Antigravity CLI (AGY)(Pilih / Ganti versi)"
echo -e "  ${GREEN}4)${RESET} Update Semua Tools   (Rilis terbaru)"
echo -e "  ${CYAN}5)${RESET} Ganti Versi Kustom   (Ketik versi bebas langsung)"
echo -e "  ${YELLOW}6)${RESET} Keluar"
echo ""
read -r -p "Masukkan pilihan [1-6]: " choice

case "$choice" in
    1)
        if choose_version "OpenCode v1" "$OPENCODE_INSTALLED" "${OPENCODE1_LIST[@]}"; then
            log_info "Memulai pemasangan OpenCode v1 versi ${SELECTED_VERSION}..."
            bash "$SCRIPT_DIR/bin/install-opencode.sh" "$SELECTED_VERSION" --force
        fi
        ;;
    2)
        if choose_version "OpenCode v2" "$OPENCODE2_INSTALLED" "${OPENCODE2_LIST[@]}"; then
            log_info "Memulai pemasangan OpenCode v2 versi ${SELECTED_VERSION}..."
            bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$SELECTED_VERSION" --force
        fi
        ;;
    3)
        if choose_version "Antigravity CLI (AGY)" "$AGY_INSTALLED" "${AGY_LIST[@]}"; then
            log_info "Memulai pemasangan Antigravity CLI versi ${SELECTED_VERSION}..."
            bash "$SCRIPT_DIR/bin/install-agy.sh" "$SELECTED_VERSION" --force
        fi
        ;;
    4)
        log_info "Mengupdate semua tools..."
        log_info "1. Mengupdate OpenCode v1 ke versi terbaru ($OPENCODE_LATEST)..."
        bash "$SCRIPT_DIR/bin/install-opencode.sh" "$OPENCODE_LATEST" --force
        log_info "2. Mengupdate OpenCode v2 ke versi terbaru ($OPENCODE2_LATEST)..."
        bash "$SCRIPT_DIR/bin/install-opencode-v2.sh" "$OPENCODE2_LATEST" --force
        log_info "3. Memasang Antigravity CLI (1.3.5 stabil)..."
        bash "$SCRIPT_DIR/bin/install-agy.sh" "1.3.5" --force
        log_ok "Semua tools berhasil diperbarui!"
        ;;
    5)
        custom_switcher
        ;;
    *)
        echo "Selesai."
        ;;
esac
