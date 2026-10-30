#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Comprehensive Test Suite for Update Checker & Version Selector (update.sh)
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE_BIN="$TOOLS_DIR/update.sh"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

PASSED=0
FAILED=0

clean_ansi() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

assert_success() {
    local test_name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo -e "  [${GREEN}PASS${RESET}] $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  [${RED}FAIL${RESET}] $test_name"
        FAILED=$((FAILED + 1))
    fi
}

assert_output_contains() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local output
    output=$("$@") || true
    local clean_out
    clean_out=$(clean_ansi "$output")
    if [[ "$clean_out" == *"$expected"* ]]; then
        echo -e "  [${GREEN}PASS${RESET}] $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  [${RED}FAIL${RESET}] $test_name"
        echo "    Expected to contain: '$expected'"
        echo "    Actual output: $clean_out"
        FAILED=$((FAILED + 1))
    fi
}

echo -e "\n${BOLD}${CYAN}=== Menjalankan Test Suite Updater termux-ai-tools ===${RESET}\n"

# Test 1: update.sh file exists and is executable
assert_success "update.sh ada dan executable" [ -x "$UPDATE_BIN" ]

# Test 2: update.sh --check executes successfully
assert_success "update.sh --check berjalan tanpa error" "$UPDATE_BIN" --check

# Test 3: Output contains OpenCode v2 upstream section
assert_output_contains "Output menampilkan section OpenCode v2" "OpenCode v2 (github.com/anomalyco/opencode)" "$UPDATE_BIN" --check

# Test 4: Output contains OpenCode v1 upstream section
assert_output_contains "Output menampilkan section OpenCode v1" "OpenCode v1 (github.com/anomalyco/opencode)" "$UPDATE_BIN" --check

# Test 5: Output contains AGY upstream section
assert_output_contains "Output menampilkan section Antigravity CLI (AGY)" "Antigravity CLI (AGY)" "$UPDATE_BIN" --check

# Test 6: Output contains latest marker
assert_output_contains "Output menandai rilis terbaru dengan badge [latest" "[latest" "$UPDATE_BIN" --check

# Test 7: Output contains status summary table
assert_output_contains "Output menampilkan tabel ringkasan status" "Ringkasan Status di Termux Anda" "$UPDATE_BIN" --check

# Test 8: Interactive version selection menu displays correctly for OpenCode v2
assert_output_contains "Menu versi v2 menampilkan [latest dan [aktif" "Pilih / Ganti Versi OpenCode v2" bash -c "printf '2\n0\n' | $UPDATE_BIN"

# Test 9: Interactive version selection menu displays correctly for AGY
assert_output_contains "Menu versi AGY menampilkan [latest dan stabil" "Pilih / Ganti Versi Antigravity CLI (AGY)" bash -c "printf '3\n0\n' | $UPDATE_BIN"

# Test 10: Option 5 opens standalone custom version switcher
assert_output_contains "Opsi 5 membuka custom version switcher" "Ganti Versi Kustom Bebas" bash -c "printf '5\n0\n' | $UPDATE_BIN"

# Test 11: Exit option 6 exits cleanly
assert_output_contains "Pilihan 6 keluar dengan selesai" "Selesai." bash -c "printf '6\n' | $UPDATE_BIN"

echo ""
echo -e "${BOLD}Hasil Pengujian:${RESET}"
echo -e "  Total Passed: ${GREEN}$PASSED${RESET}"
echo -e "  Total Failed: ${RED}$FAILED${RESET}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}✓ Semua pengujian update.sh berhasil!${RESET}\n"
    exit 0
else
    echo -e "\n${RED}${BOLD}✗ Ada pengujian yang gagal!${RESET}\n"
    exit 1
fi
